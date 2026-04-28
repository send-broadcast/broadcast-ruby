# frozen_string_literal: true

module Broadcast
  class Configuration
    attr_accessor :api_token,
                  :host,
                  :timeout,
                  :open_timeout,
                  :retry_attempts,
                  :retry_delay,
                  :logger,
                  :debug,
                  :broadcast_channel_id

    def initialize
      @api_token = nil
      @host = 'https://sendbroadcast.com'
      @timeout = 30
      @open_timeout = 10
      @retry_attempts = 3
      @retry_delay = 1
      @logger = nil
      @debug = false
      @broadcast_channel_id = nil
    end

    def validate!
      raise ConfigurationError, 'api_token is required' if api_token.nil? || api_token.to_s.strip.empty?

      self.host = host.chomp('/') if host&.end_with?('/')
    end
  end
end
