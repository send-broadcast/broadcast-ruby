# frozen_string_literal: true

module Broadcast
  module Resources
    class Segments < Base
      def list(**params)
        get('/api/v1/segments.json', params)
      end

      def get_segment(id, page: nil)
        params = page ? { page: page } : {}
        get("/api/v1/segments/#{id}.json", params)
      end

      def create(**attrs)
        post('/api/v1/segments', { segment: attrs })
      end

      def update(id, **attrs)
        patch("/api/v1/segments/#{id}", { segment: attrs })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/segments/#{id}")
      end
    end
  end
end
