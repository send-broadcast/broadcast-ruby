# frozen_string_literal: true

module Broadcast
  module Resources
    class Broadcasts < Base
      def list(**params)
        get('/api/v1/broadcasts', params)
      end

      def get_broadcast(id)
        get("/api/v1/broadcasts/#{id}")
      end

      def create(**attrs)
        post('/api/v1/broadcasts', attrs)
      end

      def update(id, **attrs)
        patch("/api/v1/broadcasts/#{id}", attrs)
      end

      def delete(id)
        @client.request(:delete, "/api/v1/broadcasts/#{id}")
      end

      def send_broadcast(id)
        post("/api/v1/broadcasts/#{id}/send_broadcast")
      end

      def schedule(id, scheduled_send_at:, scheduled_timezone:)
        post("/api/v1/broadcasts/#{id}/schedule_broadcast", {
               scheduled_send_at: scheduled_send_at,
               scheduled_timezone: scheduled_timezone
             })
      end

      def cancel_schedule(id)
        post("/api/v1/broadcasts/#{id}/cancel_schedule")
      end

      def statistics(id)
        get("/api/v1/broadcasts/#{id}/statistics")
      end

      def statistics_timeline(id, **params)
        get("/api/v1/broadcasts/#{id}/statistics/timeline", params)
      end

      def statistics_links(id, **params)
        get("/api/v1/broadcasts/#{id}/statistics/links", params)
      end
    end
  end
end
