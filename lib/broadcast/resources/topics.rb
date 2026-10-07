# frozen_string_literal: true

module Broadcast
  module Resources
    # Subscriber topics: kinds of email subscribers opt in to or out of. A topic
    # reads a top-level custom_data key (true, false, or no value) or a tag.
    # Uses the token's subscriber permissions.
    class Topics < Base
      def list(**params)
        get('/api/v1/topics.json', params)
      end

      def get_topic(id)
        get("/api/v1/topics/#{id}.json")
      end

      def create(**attrs)
        post('/api/v1/topics', { topic: attrs })
      end

      def update(id, **attrs)
        patch("/api/v1/topics/#{id}", { topic: attrs })
      end

      # Refused (422) while a broadcast or sequence uses the topic.
      def delete(id)
        @client.request(:delete, "/api/v1/topics/#{id}")
      end
    end
  end
end
