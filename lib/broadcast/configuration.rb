# frozen_string_literal: true

module Broadcast
  class Configuration
    # How to handle the `warnings` array the API returns on successful writes
    # (docs: api-response-warnings):
    #   :log    — warn through `logger` if one is set (default)
    #   :raise  — raise Broadcast::WarningError; note the write already happened
    #   :ignore — leave them on the response for the caller to inspect
    WARNINGS_MODES = %i[log raise ignore].freeze

    # Env vars use the same names as the Broadcast CLI's ~/.config/broadcast/config,
    # so a machine set up for the CLI can drive the gem with no extra config.
    ENV_HOST = 'BROADCAST_HOST'
    ENV_TOKEN = 'BROADCAST_API_TOKEN'

    attr_accessor :api_token,
                  :host,
                  :timeout,
                  :open_timeout,
                  :retry_attempts,
                  :retry_delay,
                  :max_retry_delay,
                  :warnings_mode,
                  :logger,
                  :debug,
                  :broadcast_channel_id

    def initialize
      @api_token = ENV.fetch(ENV_TOKEN, nil)
      # No default host. Broadcast is self-hosted-first — every instance lives
      # at its own domain, so any built-in guess is wrong for nearly everyone.
      @host = ENV.fetch(ENV_HOST, nil)
      @timeout = 30
      @open_timeout = 10
      @retry_attempts = 3
      @retry_delay = 1
      # Ceiling for a server-supplied Retry-After. Without it a long rate-limit
      # window would block the caller for as long as the server asked.
      @max_retry_delay = 30
      @warnings_mode = :log
      @logger = nil
      @debug = false
      @broadcast_channel_id = nil
    end

    def validate!
      raise ConfigurationError, 'api_token is required' if blank?(api_token)
      raise ConfigurationError, host_missing_message if blank?(host)

      self.host = host.to_s.strip.chomp('/')
      validate_host_scheme!
      validate_warnings_mode!
    end

    private

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def host_missing_message
      "host is required — point it at your Broadcast instance, e.g. \
Broadcast::Client.new(api_token: '...', host: 'https://mail.example.com'). \
You can also set the #{ENV_HOST} environment variable."
    end

    def validate_host_scheme!
      return if host.start_with?('http://', 'https://')

      raise ConfigurationError, "host must include a scheme (http:// or https://), got #{host.inspect}"
    end

    def validate_warnings_mode!
      self.warnings_mode = warnings_mode.to_sym
      return if WARNINGS_MODES.include?(warnings_mode)

      raise ConfigurationError,
            "warnings_mode must be one of #{WARNINGS_MODES.join(', ')}, got #{warnings_mode.inspect}"
    end
  end
end
