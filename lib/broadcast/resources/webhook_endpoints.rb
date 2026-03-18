# frozen_string_literal: true

module Broadcast
  module Resources
    class WebhookEndpoints < Base
      def list(**params)
        get('/api/v1/webhook_endpoints', params)
      end

      def get_endpoint(id)
        get("/api/v1/webhook_endpoints/#{id}")
      end

      def create(**attrs)
        post('/api/v1/webhook_endpoints', { webhook_endpoint: attrs })
      end

      def update(id, **attrs)
        patch("/api/v1/webhook_endpoints/#{id}", { webhook_endpoint: attrs })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/webhook_endpoints/#{id}")
      end

      def test(id, event_type: 'test.webhook')
        post("/api/v1/webhook_endpoints/#{id}/test", { event_type: event_type })
      end

      def deliveries(id, **params)
        get("/api/v1/webhook_endpoints/#{id}/deliveries", params)
      end
    end
  end
end
