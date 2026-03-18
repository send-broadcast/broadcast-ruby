# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Broadcast
  class Client
    attr_reader :config

    def initialize(**settings)
      @config = Configuration.new
      settings.each { |k, v| @config.public_send(:"#{k}=", v) }
      @config.validate!
    end

    # --- Transactional email ---

    def send_email(to:, subject:, body:, reply_to: nil)
      payload = { to: to, subject: subject, body: body }
      payload[:reply_to] = reply_to if reply_to
      request(:post, '/api/v1/transactionals.json', payload)
    end

    def get_email(id)
      request(:get, "/api/v1/transactionals/#{id}.json")
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

    # @api private
    def request(method, path, body_or_params = nil)
      uri = URI("#{@config.host}#{path}")

      if method == :get && body_or_params.is_a?(Hash) && body_or_params.any?
        uri.query = URI.encode_www_form(flatten_params(body_or_params))
      end

      retry_with_backoff do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = @config.open_timeout
        http.read_timeout = @config.timeout

        req = build_request(method, uri)
        req.body = body_or_params.to_json if method != :get && body_or_params.is_a?(Hash) && body_or_params.any?

        log_request(req, method == :get ? nil : body_or_params) if @config.debug

        response = http.request(req)
        log_response(response) if @config.debug
        handle_response(response)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Broadcast::TimeoutError, "Request timeout: #{e.message}"
    end

    private

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

    def handle_response(response)
      case response.code.to_i
      when 200, 201
        return {} if response.body.nil? || response.body.strip.empty?

        JSON.parse(response.body)
      when 401
        raise AuthenticationError, parse_error(response) || 'Authentication failed'
      when 404
        raise NotFoundError, parse_error(response) || 'Resource not found'
      when 422
        raise ValidationError, parse_error(response) || 'Validation failed'
      when 429
        raise RateLimitError, parse_error(response) || 'Rate limit exceeded'
      when 500, 502, 503, 504
        raise APIError, parse_error(response) || "Server error (#{response.code})"
      else
        raise APIError, parse_error(response) || "Unexpected response: #{response.code}"
      end
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
