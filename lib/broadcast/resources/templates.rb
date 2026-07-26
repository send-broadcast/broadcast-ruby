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

      # Create a template. Attrs are wrapped under `template:` on the wire.
      #
      # Content:
      #   label:, subject:, preheader:, body:, html_body:
      #
      # Confirmation templates (double opt-in):
      #   template_purpose:          marks the template's role, e.g. 'confirmation'
      #   confirmation_text:         copy shown in the confirmation email
      #   default_confirmation:      make this the channel's default confirmation template
      #   confirmation_page_settings: per-state page copy, keyed by state, each
      #                              taking { heading:, body: } — e.g.
      #                              { 'confirmed' => { heading: 'You're in',
      #                                                 body: 'Thanks for confirming.' },
      #                                'expired'   => { heading: 'Link expired', body: '...' } }
      #
      # Anything the server doesn't recognize comes back as an
      # `unrecognized_parameter` warning on the response rather than an error.
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
