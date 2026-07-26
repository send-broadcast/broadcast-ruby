# frozen_string_literal: true

module Broadcast
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class APIError < Error; end

  class AuthenticationError < APIError; end

  class AuthorizationError < APIError; end

  class NotFoundError < APIError; end

  # 409 — an in-flight request is already using this Idempotency-Key. The
  # original request is still processing; retrying after a short pause will
  # either replay its stored response or run fresh if it failed.
  class ConflictError < APIError; end

  class RateLimitError < APIError
    # Seconds the server asked us to wait, parsed from the Retry-After header.
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end

  class ValidationError < Error; end

  class TimeoutError < Error; end

  class DeliveryError < Error; end

  # Raised instead of returning when config.warnings_mode is :raise and a 2xx
  # response carried warnings. The request DID succeed — the write happened.
  # Callers rescuing this must not assume anything was rolled back.
  class WarningError < Error
    attr_reader :warnings, :response

    def initialize(warnings, response = nil)
      @warnings = warnings
      @response = response
      super("API returned #{warnings.size} warning(s): #{warnings.join('; ')}")
    end
  end
end
