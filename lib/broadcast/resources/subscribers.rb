# frozen_string_literal: true

module Broadcast
  module Resources
    class Subscribers < Base
      def list(**params)
        get('/api/v1/subscribers.json', params)
      end

      def find(email:)
        get('/api/v1/subscribers/find.json', { email: email })
      end

      def create(**attrs)
        post('/api/v1/subscribers.json', { subscriber: attrs })
      end

      def update(email, **attrs)
        patch('/api/v1/subscribers.json', { email: email, subscriber: attrs })
      end

      def add_tags(email, tags)
        post('/api/v1/subscribers/add_tag.json', { email: email, tags: tags })
      end

      def remove_tags(email, tags)
        @client.request(:delete, '/api/v1/subscribers/remove_tag.json', { email: email, tags: tags })
      end

      def deactivate(email)
        post('/api/v1/subscribers/deactivate.json', { email: email })
      end

      def activate(email)
        post('/api/v1/subscribers/activate.json', { email: email })
      end

      def unsubscribe(email)
        post('/api/v1/subscribers/unsubscribe.json', { email: email })
      end

      def resubscribe(email)
        post('/api/v1/subscribers/resubscribe.json', { email: email })
      end

      def redact(email)
        post('/api/v1/subscribers/redact.json', { email: email })
      end
    end
  end
end
