# frozen_string_literal: true

module Broadcast
  module Resources
    class Subscribers < Base
      # List subscribers (250 per page, with `pagination` metadata; pass `page:`).
      #
      # Filters, all optional and combinable:
      #   is_active:            true | false
      #   source:               exact match on the source string
      #   created_after:        ISO-8601 timestamp
      #   created_before:       ISO-8601 timestamp
      #   tags:                 array — AND logic, subscriber must have all of them
      #   email:                partial (case-insensitive) match, not exact
      #   confirmation_status:  'confirmed' | 'unconfirmed'
      #   custom_data:          hash — JSONB containment, e.g. { plan: 'pro' }
      #
      # An unparseable created_after/created_before is *ignored* by the server
      # rather than rejected; it comes back as a `parameter_ignored` warning on
      # the response, so a bad timestamp silently widens the result set unless
      # you check `result.warnings`.
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
      #
      # Admin tokens only:
      #   confirmed_at:                backdate the confirmation timestamp on create.
      #                                Intended for migrating an already-confirmed list off
      #                                another provider. Ignored (with a warning) on update,
      #                                and ignored entirely for channel-scoped tokens.
      #
      # Note `unsubscribed_at` is never settable here — use `unsubscribe(email)`.
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
