# frozen_string_literal: true

require 'time'

module Broadcast
  # A single entry from the API's `warnings` array (docs: api-response-warnings).
  # The API raises these on successful 2xx responses when it accepted the request
  # but ignored part of it — an unrecognized parameter, a parameter that only
  # applies in another mode, a value the server overrode.
  #
  # `param` is a dot-path to the offending parameter (e.g. "subscriber.foo").
  # The API never includes submitted values, so a warning is safe to log.
  Warning = Struct.new(:code, :param, :message) do
    def to_s
      param ? "[#{code}] #{param}: #{message}" : "[#{code}] #{message}"
    end
  end

  # Parsed X-RateLimit-* response headers. `reset` is the time the current
  # window rolls over, not a duration.
  RateLimit = Struct.new(:limit, :remaining, :reset)

  # The value returned by every JSON API call.
  #
  # Response subclasses Hash rather than wrapping it, so everything that worked
  # against the raw parsed body still works — `result['id']`, `result.is_a?(Hash)`,
  # `result.dig(...)`, equality against a plain Hash. The response metadata the
  # API sends alongside the body is exposed as extra readers.
  #
  #   result = client.subscribers.create(email: 'user@example.com', foo: 'bar')
  #   result['id']                  # => 42        (unchanged from v0.2)
  #   result.warnings               # => [#<Warning code="unrecognized_parameter" ...>]
  #   result.rate_limit.remaining   # => 118
  #   result.status                 # => 201
  #
  # Non-Hash JSON bodies (a bare array) are returned as-is and carry no metadata.
  class Response < Hash
    attr_reader :status, :headers

    class << self
      # Wraps a parsed JSON body when it is a Hash; passes anything else through.
      def build(parsed, status:, headers: {})
        return parsed unless parsed.is_a?(::Hash)

        response = new
        response.replace(parsed)
        response.attach_metadata(status: status, headers: headers)
        response
      end
    end

    # @api private — set once by .build immediately after construction
    def attach_metadata(status:, headers:)
      @status = status
      @headers = headers
      self
    end

    def warnings
      @warnings ||= Array(self['warnings']).filter_map do |entry|
        next unless entry.is_a?(::Hash)

        Warning.new(code: entry['code'], param: entry['param'], message: entry['message'])
      end
    end

    def warnings?
      !warnings.empty?
    end

    def rate_limit
      return @rate_limit if defined?(@rate_limit)

      limit = header('x-ratelimit-limit')
      @rate_limit = if limit.nil?
                      nil
                    else
                      RateLimit.new(
                        limit: limit.to_i,
                        remaining: header('x-ratelimit-remaining')&.to_i,
                        reset: parse_time(header('x-ratelimit-reset'))
                      )
                    end
    end

    # True when the API replayed a stored response for a repeated
    # Idempotency-Key rather than performing the write again.
    def idempotent_replay?
      header('idempotency-replayed') == 'true'
    end

    private

    def header(name)
      (@headers || {})[name]
    end

    def parse_time(value)
      value && Time.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end
