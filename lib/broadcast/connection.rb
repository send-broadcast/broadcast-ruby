# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Broadcast
  # HTTP transport. Owns request building, response/error mapping, retries,
  # redirects, and debug logging. Split out of Client so Client stays a thin
  # facade over configuration and resource sub-clients.
  class Connection
    MAX_REDIRECTS = 3
    REDIRECT_CODES = [301, 302, 307, 308].freeze

    ERROR_MAPPING = {
      401 => [AuthenticationError, 'Authentication failed'],
      403 => [AuthorizationError, 'Not authorized'],
      404 => [NotFoundError, 'Resource not found'],
      409 => [ConflictError, 'A request with this Idempotency-Key is still being processed'],
      422 => [ValidationError, 'Validation failed']
    }.freeze
    private_constant :ERROR_MAPPING

    def initialize(config)
      @config = config
      @debug_logger = DebugLogger.new(config)
    end

    # @param raw [Boolean] return the response body as a String instead of
    #   parsing it as JSON — for text/plain endpoints such as /api/v1/skill.
    def request(method, path, payload = nil, headers: {}, raw: false)
      uri = build_uri(path, method, payload)
      context = { headers: headers, raw: raw, redirects: 0 }

      retry_with_backoff { execute(method, uri, payload, context) }
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Broadcast::TimeoutError, "Request timeout: #{e.message}"
    end

    private

    def build_uri(path, method, payload)
      uri = URI("#{@config.host}#{path}")
      uri.query = URI.encode_www_form(flatten_params(payload)) if method == :get && payload_present?(payload)
      uri
    end

    def execute(method, uri, payload, context)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @config.open_timeout
      http.read_timeout = @config.timeout

      req = build_request(method, uri, context[:headers])
      req.body = payload.to_json if method != :get && payload_present?(payload)

      @debug_logger.request(req, method == :get ? nil : payload)
      response = http.request(req)
      @debug_logger.response(response)

      return follow_redirect(response, method, uri, context) if redirect?(response)

      handle_response(response, raw: context[:raw])
    end

    # --- Redirects -----------------------------------------------------------
    #
    # A redirect nearly always means a misconfigured `host` (http vs https, a
    # bare apex that redirects to www, a stale domain). Two things are never
    # followed:
    #
    #   - writes, because replaying a send against an unexpected origin is worse
    #     than failing; and
    #   - anything that changes host, because every request carries
    #     `Authorization: Bearer <token>` and following would hand the API token
    #     to whatever the redirect points at.
    #
    # Both raise with the destination named, so a misconfigured host diagnoses
    # itself instead of failing mysteriously.

    def redirect?(response)
      REDIRECT_CODES.include?(response.code.to_i)
    end

    def follow_redirect(response, method, uri, context)
      location = response['location']
      redirects = context[:redirects]

      if method != :get
        raise APIError,
              "Host redirected #{method.to_s.upcase} #{uri} to #{location || '(no Location header)'}. " \
              'Set `host` to the final URL — writes are not followed automatically.'
      end

      raise APIError, "Redirect from #{uri} had no Location header" if location.nil?
      raise APIError, "Too many redirects (#{MAX_REDIRECTS}) starting at #{uri}" if redirects >= MAX_REDIRECTS

      target = URI.join(uri, location)
      raise APIError, cross_host_redirect_message(uri, target) unless same_host?(uri, target)

      # Query string is already baked into the current URI; don't re-append it.
      execute(:get, target, nil, context.merge(redirects: redirects + 1))
    end

    def same_host?(from, to)
      from.host&.downcase == to.host&.downcase
    end

    def cross_host_redirect_message(from, target)
      "Host redirected #{from} to a different host (#{target}). Not following it — " \
        'the request carries your API token. Set `host` to the correct instance URL.'
    end

    # --- Requests ------------------------------------------------------------

    def build_request(method, uri, extra_headers)
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
      extra_headers.each { |key, value| req[key.to_s] = value.to_s unless value.nil? }
      req
    end

    def payload_present?(payload)
      payload.is_a?(Hash) && payload.any?
    end

    # --- Responses -----------------------------------------------------------

    def handle_response(response, raw:)
      code = response.code.to_i
      return build_success(response, raw: raw) if code.between?(200, 299)

      raise_rate_limit_error(response) if code == 429

      if (mapping = ERROR_MAPPING[code])
        klass, default = mapping
        raise klass, parse_error(response) || default
      end

      raise APIError, parse_error(response) || "Server error (#{code})" if code >= 500

      raise APIError, parse_error(response) || "Unexpected response: #{code}"
    end

    def build_success(response, raw:)
      return raw_body(response) if raw

      result = Response.build(
        parse_success_body(response),
        status: response.code.to_i,
        headers: extract_headers(response)
      )
      handle_warnings(result)
      result
    end

    # Raw endpoints serve two very different things: text (/api/v1/skill) and
    # binary file assets. Trusting the body's default encoding would tag PNG
    # bytes as UTF-8 and blow up on the first regex match, so only keep a text
    # encoding when the server actually declared a charset.
    def raw_body(response)
      body = response.body.to_s
      return body if response.type_params['charset']

      body.dup.force_encoding(Encoding::BINARY)
    end

    def raise_rate_limit_error(response)
      retry_after = response['retry-after']&.to_i
      raise RateLimitError.new(parse_error(response) || 'Rate limit exceeded', retry_after: retry_after)
    end

    def extract_headers(response)
      headers = {}
      response.each_header { |key, value| headers[key.downcase] = value }
      headers
    end

    def parse_success_body(response)
      return {} if response.body.nil? || response.body.strip.empty?

      JSON.parse(response.body)
    rescue JSON::ParserError
      # A 2xx that isn't JSON (an HTML error page from a proxy, say). Surface it
      # as an empty body rather than exploding — `raw: true` is the way to read
      # non-JSON endpoints deliberately.
      {}
    end

    def parse_error(response)
      body = JSON.parse(response.body)
      body['error'] || format_errors(body['errors'])
    rescue JSON::ParserError, TypeError
      nil
    end

    # ActiveModel errors arrive as {"field" => ["msg", ...]}
    def format_errors(errors)
      return nil if errors.nil?
      return errors.join(', ') if errors.is_a?(Array)
      return nil unless errors.is_a?(Hash)

      errors.map { |field, messages| "#{field} #{Array(messages).join(', ')}" }.join('; ')
    end

    # --- Warnings ------------------------------------------------------------

    def handle_warnings(result)
      return unless result.is_a?(Response) && result.warnings?

      case @config.warnings_mode
      when :raise then raise WarningError.new(result.warnings, result)
      when :log then @debug_logger.warnings(result.warnings)
      end
    end

    # --- Retries -------------------------------------------------------------

    def retry_with_backoff
      attempts = 0
      begin
        attempts += 1
        yield
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise if attempts >= @config.retry_attempts

        sleep(@config.retry_delay * attempts)
        retry
      rescue RateLimitError => e
        raise if attempts >= @config.retry_attempts

        sleep(rate_limit_delay(e, attempts))
        retry
      rescue APIError => e
        raise unless attempts < @config.retry_attempts && e.message.include?('Server error')

        sleep(@config.retry_delay * attempts)
        retry
      end
    end

    # Honour Retry-After when the server sent one, but never sleep longer than
    # max_retry_delay — a wide rate-limit window shouldn't hang the caller.
    def rate_limit_delay(error, attempts)
      requested = error.retry_after || (@config.retry_delay * attempts)
      [requested, @config.max_retry_delay].min
    end

    # --- Params --------------------------------------------------------------

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
  end
end
