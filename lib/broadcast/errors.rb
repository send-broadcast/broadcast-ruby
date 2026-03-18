# frozen_string_literal: true

module Broadcast
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class APIError < Error; end

  class AuthenticationError < APIError; end

  class NotFoundError < APIError; end

  class RateLimitError < APIError; end

  class ValidationError < Error; end

  class TimeoutError < Error; end
end
