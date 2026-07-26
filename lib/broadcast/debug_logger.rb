# frozen_string_literal: true

require 'json'

module Broadcast
  # Debug logging for HTTP traffic, kept separate from Connection so the
  # redaction rules live in one obvious place.
  #
  # Request bodies routinely carry SMTP passwords and provider API keys
  # (email server create/update), so nothing is logged verbatim — matching keys
  # are replaced before the body is serialized.
  class DebugLogger
    SENSITIVE_KEYS = %w[
      smtp_password aws_access_key_id aws_secret_access_key
      outbound_aws_access_key_id outbound_aws_secret_access_key
      postmark_api_token inboxroad_api_token smtp_com_api_key
      api_key api_token password secret
    ].freeze

    def initialize(config)
      @config = config
    end

    def enabled?
      @config.debug && !@config.logger.nil?
    end

    def request(http_request, body)
      return unless enabled?

      @config.logger.debug("[Broadcast] #{http_request.method} #{http_request.uri}")
      return unless body.is_a?(Hash) && body.any?

      @config.logger.debug("[Broadcast] Body: #{redact(body).to_json}")
    end

    def response(http_response)
      return unless enabled?

      @config.logger.debug("[Broadcast] Response: #{http_response.code} #{http_response.body}")
    end

    def warnings(warnings)
      return unless @config.logger

      warnings.each { |warning| @config.logger.warn("[Broadcast] #{warning}") }
    end

    private

    def redact(value)
      case value
      when Hash
        value.to_h do |key, nested|
          SENSITIVE_KEYS.include?(key.to_s) ? [key, '[REDACTED]'] : [key, redact(nested)]
        end
      when Array
        value.map { |item| redact(item) }
      else
        value
      end
    end
  end
end
