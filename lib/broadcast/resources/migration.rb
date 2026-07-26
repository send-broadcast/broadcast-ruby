# frozen_string_literal: true

module Broadcast
  module Resources
    # Read-only export endpoints under /api/migration/v1 — the surface behind
    # backups and instance-to-instance migration.
    #
    # Two things differ from the v1 API:
    #
    # 1. **Admin tokens only.** Channel-scoped tokens are rejected outright;
    #    the controller looks up AdminApiToken and nothing else.
    # 2. **broadcast_channel_id is required on every call.** Set it once via
    #    `Client.new(broadcast_channel_id:)` or `client.with_channel(id)` and
    #    the gem attaches it automatically; otherwise pass it per call.
    #
    # Every list endpoint pages with `limit:` (1..250, default 250) and
    # `offset:`, and returns `{"data" => [...], "pagination" => {...}}`.
    class Migration < Base
      # Endpoints that are a plain paginated list of the channel's records.
      COLLECTIONS = %i[
        channels subscribers templates segments sequences email_servers
        opt_in_forms broadcasts outbound_receipts webhook_endpoints tokens
        suppressions tags users link_redirects link_clicks subscriber_histories
        file_assets
      ].freeze

      COLLECTIONS.each do |collection|
        define_method(collection) do |**params|
          get("/api/migration/v1/#{collection}", params)
        end
      end

      # Export summary: format version, channel identity, per-resource counts,
      # and recent-history totals. Call this first to size an export.
      #
      # @param days_history [Integer] window for the time-bounded counts
      #   (broadcasts, receipts, histories). Server clamps to 1..365, default 90.
      def manifest(**params)
        get('/api/migration/v1/manifest', params)
      end

      # Binary contents of a stored file asset. Returns a String of bytes, not
      # JSON — write it straight to disk.
      def download_file_asset(id, **params)
        @client.request(:get, "/api/migration/v1/file_assets/#{id}/download", params, raw: true)
      end

      # Pages through a collection, yielding each record.
      #
      #   client.migration.each_record(:subscribers) { |sub| csv << sub }
      #
      # Stops when the server reports `has_more: false`, so it stays correct if
      # the page size is clamped server-side.
      def each_record(collection, limit: 250, **params, &block)
        return enum_for(:each_record, collection, limit: limit, **params) unless block_given?

        offset = 0
        loop do
          page = public_send(collection, limit: limit, offset: offset, **params)
          records = Array(page['data'])
          records.each(&block)

          pagination = page['pagination'] || {}
          break unless pagination['has_more']

          # Advance by what the server actually returned — it clamps `limit`.
          advanced = pagination['limit'] || records.size
          break if advanced.to_i.zero?

          offset += advanced.to_i
        end
      end
    end
  end
end
