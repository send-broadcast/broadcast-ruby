# frozen_string_literal: true

module Broadcast
  module Resources
    # The installation-wide suppression list. Addresses on it never receive
    # mail from any channel. All operations require an admin (system) API
    # token — a channel token gets a 401.
    #
    # There is deliberately no `check` here: checking is a per-channel
    # question (it reads the channel list too), so it lives on Suppressions.
    class GlobalSuppressions < Base
      # List global suppressions (250 per page, with `pagination` metadata;
      # pass `page:`). Optional `email:` filters by partial match.
      def list(**params)
        get('/api/v1/global_suppressions.json', params)
      end

      # Add an address to the global list. Already-suppressed is a success
      # (200 instead of 201).
      def add(email)
        post('/api/v1/global_suppressions.json', { email: email })
      end

      # Remove an address from the global list only. Channels that suppressed
      # the same address on their own account keep their block.
      def remove(email)
        @client.request(:delete, '/api/v1/global_suppressions.json', { email: email })
      end

      # Add up to 10,000 addresses at once. Idempotent. Returns `added`,
      # `already_suppressed`, and `invalid` counts.
      def bulk_add(emails)
        post('/api/v1/global_suppressions/bulk.json', { emails: emails })
      end

      # Remove up to 10,000 addresses at once. Returns `removed` and
      # `not_found` counts.
      def bulk_remove(emails)
        @client.request(:delete, '/api/v1/global_suppressions/bulk.json', { emails: emails })
      end
    end
  end
end
