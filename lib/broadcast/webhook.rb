# frozen_string_literal: true

require 'openssl'
require 'base64'

module Broadcast
  module Webhook
    TIMESTAMP_TOLERANCE = 300 # 5 minutes

    module_function

    def verify(payload, signature_header, timestamp_header, secret:, now: nil)
      return false if payload.nil? || signature_header.nil? || timestamp_header.nil? || secret.nil?

      timestamp = timestamp_header.to_i
      current_time = (now || Time.now).to_i
      return false unless timestamp_valid?(timestamp, current_time)

      expected = compute_signature(payload, timestamp, secret)
      actual = extract_signature(signature_header)
      return false if actual.nil?

      secure_compare(expected, actual)
    end

    def compute_signature(payload, timestamp, secret)
      signed_content = "#{timestamp}.#{payload}"
      hmac = OpenSSL::HMAC.digest('SHA256', secret, signed_content)
      Base64.strict_encode64(hmac)
    end

    def timestamp_valid?(timestamp, current_time = Time.now.to_i)
      (current_time - timestamp).abs <= TIMESTAMP_TOLERANCE
    end

    def extract_signature(header)
      return nil unless header&.start_with?('v1,')

      sig = header.delete_prefix('v1,')
      return nil if sig.empty?

      sig
    end

    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      OpenSSL.fixed_length_secure_compare(a, b)
    end
  end
end
