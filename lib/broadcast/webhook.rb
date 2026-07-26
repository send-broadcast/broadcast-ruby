# frozen_string_literal: true

require 'openssl'
require 'base64'

module Broadcast
  module Webhook
    TIMESTAMP_TOLERANCE = 300 # 5 minutes

    # Every event type a webhook endpoint can subscribe to, mirroring
    # WebhookEndpoint::AVAILABLE_EVENT_TYPES server-side. Use these when
    # creating an endpoint — an unknown event type is dropped silently.
    EMAIL_EVENTS = %w[
      email.sent email.delivered email.delivery_delayed email.complained
      email.bounced email.opened email.clicked email.failed
    ].freeze

    SUBSCRIBER_EVENTS = %w[
      subscriber.created subscriber.updated subscriber.deleted
      subscriber.subscribed subscriber.unsubscribed subscriber.bounced
      subscriber.complained
    ].freeze

    BROADCAST_EVENTS = %w[
      broadcast.scheduled broadcast.queueing broadcast.sending broadcast.sent
      broadcast.failed broadcast.partial_failure broadcast.aborted
      broadcast.paused
    ].freeze

    SEQUENCE_EVENTS = %w[
      sequence.subscriber_added sequence.subscriber_completed
      sequence.subscriber_moved sequence.subscriber_removed
      sequence.subscriber_paused sequence.subscriber_resumed
      sequence.subscriber_error
    ].freeze

    # Delivery-machinery events, not content events.
    SYSTEM_EVENTS = %w[message.attempt.exhausted test.webhook].freeze

    EVENT_TYPES = (
      EMAIL_EVENTS + SUBSCRIBER_EVENTS + BROADCAST_EVENTS + SEQUENCE_EVENTS + SYSTEM_EVENTS
    ).freeze

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
