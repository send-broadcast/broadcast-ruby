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

      # Create or upsert a subscriber.
      #
      # Subscriber attributes (wrapped under `subscriber:` on the wire):
      #   email:, first_name:, last_name:, is_active:, source:,
      #   subscribed_at:, ip_address:, tags: [...], custom_data: {...}
      #
      # Top-level options (NOT wrapped under `subscriber:`):
      #   double_opt_in:               true | { reply_to:, confirmation_template_id:, include_unsubscribe_link: }
      #                                When set, the subscriber is created in unconfirmed state
      #                                and a confirmation email is queued.
      #   confirmation_template_id:    custom confirmation template (used with double_opt_in: true)
      def create(**attrs)
        double_opt_in = attrs.delete(:double_opt_in)
        confirmation_template_id = attrs.delete(:confirmation_template_id)

        payload = { subscriber: attrs }
        payload[:double_opt_in] = double_opt_in unless double_opt_in.nil?
        payload[:confirmation_template_id] = confirmation_template_id unless confirmation_template_id.nil?

        post('/api/v1/subscribers.json', payload)
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
