# frozen_string_literal: true

module Broadcast
  module Resources
    class EmailServers < Base
      # Fields the API returns redacted (bullet-masked). When updating, never
      # round-trip these values back from a fetch — the gem strips them out
      # of the payload (with a logger warning) to prevent corrupting credentials.
      REDACTED_FIELDS = %i[
        smtp_password
        aws_access_key_id
        aws_secret_access_key
        outbound_aws_access_key_id
        outbound_aws_secret_access_key
        postmark_api_token
        inboxroad_api_token
        smtp_com_api_key
      ].freeze

      # Matches the API's redaction shape: 8 bullets, OR 4-char prefix + bullets + 4-char suffix.
      REDACTED_PATTERN = /\A(?:•{8}|.{0,4}•+.{0,4})\z/

      def list(limit: nil, offset: nil)
        params = {}
        params[:limit] = limit unless limit.nil?
        params[:offset] = offset unless offset.nil?
        get('/api/v1/email_servers', params)
      end

      def get_email_server(id)
        get("/api/v1/email_servers/#{id}")
      end

      def create(**attrs)
        post('/api/v1/email_servers', { email_server: attrs })
      end

      # Update an email server. Attrs are wrapped under `email_server:` on the wire.
      #
      # CAUTION: API responses redact credential fields (e.g. `smtp_password`)
      # with bullet characters. Never echo a fetched response back into update —
      # this method scrubs values that match the redaction pattern, but you
      # should pass only the fields you actually want to change.
      def update(id, **attrs)
        scrubbed = scrub_redacted(attrs)
        patch("/api/v1/email_servers/#{id}", { email_server: scrubbed })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/email_servers/#{id}")
      end

      def test_connection(id)
        post("/api/v1/email_servers/#{id}/test_connection")
      end

      # Copy an email server to another channel. Requires an admin/system token.
      # In SaaS mode, target_channel_id is scoped to the token creator's account.
      def copy_to_channel(id, target_channel_id:)
        post("/api/v1/email_servers/#{id}/copy_to_channel", { target_channel_id: target_channel_id })
      end

      private

      def scrub_redacted(attrs)
        scrubbed = {}
        attrs.each do |key, value|
          if REDACTED_FIELDS.include?(key.to_sym) && value.is_a?(String) && value.match?(REDACTED_PATTERN)
            warn_redacted(key)
            next
          end
          scrubbed[key] = value
        end
        scrubbed
      end

      def warn_redacted(field)
        msg = "[broadcast-ruby] Dropped redacted #{field} from update payload — " \
              'pass the real credential or omit the field'
        if @client.config.logger
          @client.config.logger.warn(msg)
        else
          Kernel.warn(msg)
        end
      end
    end
  end
end
