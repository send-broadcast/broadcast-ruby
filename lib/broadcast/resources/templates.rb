# frozen_string_literal: true

module Broadcast
  module Resources
    class Templates < Base
      def list(**params)
        get('/api/v1/templates', params)
      end

      def get_template(id)
        get("/api/v1/templates/#{id}")
      end

      def create(**attrs)
        post('/api/v1/templates', { template: attrs })
      end

      def update(id, **attrs)
        patch("/api/v1/templates/#{id}", { template: attrs })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/templates/#{id}")
      end
    end
  end
end
