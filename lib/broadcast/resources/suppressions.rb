# frozen_string_literal: true

module Broadcast
  module Resources
    # The current channel's suppression list. Addresses on it never receive
    # broadcasts, sequences, or transactionals from this channel.
    #
    # The installation-wide list is a separate resource — see
    # GlobalSuppressions — but `check` reads across both on purpose: it
    # answers the question an integration actually asks, "will this address
    # receive mail?".
    class Suppressions < Base
      # List the channel's suppressions (250 per page, with `pagination`
      # metadata; pass `page:`). Optional `email:` filters by partial,
      # case-insensitive match.
      def list(**params)
        get('/api/v1/suppressions.json', params)
      end

      # Add an address to the channel's suppression list.
      #
      # Adding an address that is already suppressed is a success (the server
      # answers 200 instead of 201), so callers do not have to check first.
      def add(email)
        post('/api/v1/suppressions.json', { email: email })
      end

      # Remove an address from the channel's suppression list. Returns
      # `removed: false` (not an error) when the address was not on it.
      # Does not touch the global list.
      def remove(email)
        @client.request(:delete, '/api/v1/suppressions.json', { email: email })
      end

      # Add up to 10,000 addresses at once. Idempotent: a retried batch cannot
      # duplicate. Returns `added`, `already_suppressed`, and `invalid` counts.
      def bulk_add(emails)
        post('/api/v1/suppressions/bulk.json', { emails: emails })
      end

      # Remove up to 10,000 addresses at once. Returns `removed` and
      # `not_found` counts.
      def bulk_remove(emails)
        @client.request(:delete, '/api/v1/suppressions/bulk.json', { emails: emails })
      end

      # Will this address receive mail? Reads across both the global and the
      # channel list — a globally blocked address reports `suppressed: true`
      # here even though it is absent from the channel's own list. The
      # response's `scope` says which list matched.
      def check(email)
        get('/api/v1/suppressions/check.json', { email: email })
      end
    end
  end
end
