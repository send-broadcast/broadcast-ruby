# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Broadcast
  class Client
    CHANNEL_OVERRIDE_KEY = :__broadcast_ruby_channel_override

    attr_reader :config

    def initialize(**settings)
      @config = Configuration.new
      settings.each { |k, v| @config.public_send(:"#{k}=", v) }
      @config.validate!
    end

    # --- Channel scoping (admin/system tokens) ---

    # Run a block with a temporary broadcast_channel_id override that will be
    # auto-included on every request inside the block. Useful for admin/system
    # tokens that need to scope each call to a specific channel.
    #
    #   client.with_channel(123) do
    #     client.email_servers.list
    #   end
    def with_channel(broadcast_channel_id)
      key = channel_override_key
      previous = Thread.current[key]
      Thread.current[key] = broadcast_channel_id
      yield self
    ensure
      Thread.current[key] = previous
    end

    # --- Transactional email (convenience shims) ---

    # Thin convenience wrapper around `transactionals.create`. Use
    # `client.transactionals.create` directly for template_id, double_opt_in,
    # preheader, and other advanced options.
    def send_email(to:, subject: nil, body: nil, reply_to: nil)
      transactionals.create(to: to, subject: subject, body: body, reply_to: reply_to)
    end

    def get_email(id)
      transactionals.get_transactional(id)
    end

    # --- Resource sub-clients ---

    def subscribers
      @subscribers ||= Resources::Subscribers.new(self)
    end

    def sequences
      @sequences ||= Resources::Sequences.new(self)
    end

    def broadcasts
      @broadcasts ||= Resources::Broadcasts.new(self)
    end

    def segments
      @segments ||= Resources::Segments.new(self)
    end

    def templates
      @templates ||= Resources::Templates.new(self)
    end

    def webhook_endpoints
      @webhook_endpoints ||= Resources::WebhookEndpoints.new(self)
    end

    def transactionals
      @transactionals ||= Resources::Transactionals.new(self)
    end

    def opt_in_forms
      @opt_in_forms ||= Resources::OptInForms.new(self)
    end

    def email_servers
      @email_servers ||= Resources::EmailServers.new(self)
    end

    # @api private
    def request(method, path, body_or_params = nil)
      payload = inject_channel_scope(body_or_params)
      uri = build_uri(path, method, payload)

      retry_with_backoff { execute(method, uri, payload) }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Broadcast::TimeoutError, "Request timeout: #{e.message}"
    end

    private

    def channel_override_key
      :"#{CHANNEL_OVERRIDE_KEY}_#{object_id}"
    end

    def active_channel_id
      Thread.current[channel_override_key] || @config.broadcast_channel_id
    end

    # Auto-include broadcast_channel_id in request payload when configured (or
    # set via with_channel) and not already specified by the caller.
    def inject_channel_scope(body_or_params)
      channel_id = active_channel_id
      return body_or_params if channel_id.nil?

      payload = body_or_params.is_a?(Hash) ? body_or_params.dup : {}
      return payload if payload[:broadcast_channel_id] || payload['broadcast_channel_id']

      payload[:broadcast_channel_id] = channel_id
      payload
    end

    def build_uri(path, method, payload)
      uri = URI("#{@config.host}#{path}")
      uri.query = URI.encode_www_form(flatten_params(payload)) if method == :get && payload_present?(payload)
      uri
    end

    def execute(method, uri, payload)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @config.open_timeout
      http.read_timeout = @config.timeout

      req = build_request(method, uri)
      req.body = payload.to_json if method != :get && payload_present?(payload)

      log_request(req, method == :get ? nil : payload) if @config.debug
      response = http.request(req)
      log_response(response) if @config.debug
      handle_response(response)
    end

    def payload_present?(payload)
      payload.is_a?(Hash) && payload.any?
    end

    def build_request(method, uri)
      klass = case method
              when :get then Net::HTTP::Get
              when :post then Net::HTTP::Post
              when :patch then Net::HTTP::Patch
              when :delete then Net::HTTP::Delete
              else raise ArgumentError, "Unsupported HTTP method: #{method}"
              end

      req = klass.new(uri)
      req['Authorization'] = "Bearer #{@config.api_token}"
      req['Content-Type'] = 'application/json'
      req['User-Agent'] = "broadcast-ruby/#{Broadcast::VERSION}"
      req
    end

    ERROR_MAPPING = {
      401 => [AuthenticationError, 'Authentication failed'],
      403 => [AuthorizationError, 'Not authorized'],
      404 => [NotFoundError, 'Resource not found'],
      422 => [ValidationError, 'Validation failed'],
      429 => [RateLimitError, 'Rate limit exceeded']
    }.freeze
    SERVER_ERROR_CODES = [500, 502, 503, 504].freeze
    private_constant :ERROR_MAPPING, :SERVER_ERROR_CODES

    def handle_response(response)
      code = response.code.to_i
      return parse_success_body(response) if [200, 201].include?(code)

      if (mapping = ERROR_MAPPING[code])
        klass, default = mapping
        raise klass, parse_error(response) || default
      end

      raise APIError, parse_error(response) || "Server error (#{code})" if SERVER_ERROR_CODES.include?(code)

      raise APIError, parse_error(response) || "Unexpected response: #{code}"
    end

    def parse_success_body(response)
      return {} if response.body.nil? || response.body.strip.empty?

      JSON.parse(response.body)
    end

    def parse_error(response)
      JSON.parse(response.body)['error']
    rescue JSON::ParserError
      nil
    end

    def retry_with_backoff
      attempts = 0
      begin
        attempts += 1
        yield
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise if attempts >= @config.retry_attempts

        sleep(@config.retry_delay * attempts)
        retry
      rescue APIError => e
        raise unless attempts < @config.retry_attempts && e.message.include?('Server error')

        sleep(@config.retry_delay * attempts)
        retry
      end
    end

    def flatten_params(params)
      result = []
      params.each do |key, value|
        case value
        when Array
          value.each { |v| result << ["#{key}[]", v.to_s] }
        when Hash
          value.each { |k, v| result << ["#{key}[#{k}]", v.to_s] }
        when nil
          next
        else
          result << [key.to_s, value.to_s]
        end
      end
      result
    end

    def log_request(request, body)
      return unless @config.logger

      @config.logger.debug("[Broadcast] #{request.method} #{request.uri}")
      @config.logger.debug("[Broadcast] Body: #{body.to_json}") if body.is_a?(Hash) && body.any?
    end

    def log_response(response)
      return unless @config.logger

      @config.logger.debug("[Broadcast] Response: #{response.code} #{response.body}")
    end
  end
end
