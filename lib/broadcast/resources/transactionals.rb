# frozen_string_literal: true

module Broadcast
  module Resources
    class Transactionals < Base
      # Send a transactional email.
      #
      # Required:
      #   to:      recipient email address
      #
      # One of subject/body or template_id is required (template_id resolves
      # subject and body server-side; subject/body override the template).
      #
      # Optional:
      #   subject:, body:, preheader:
      #   reply_to:
      #   template_id:                 resolve subject/body/preheader from a Template
      #   include_unsubscribe_link:    boolean
      #   double_opt_in:               true | { reply_to:, confirmation_template_id:, include_unsubscribe_link: }
      #                                Holds the email until the recipient confirms.
      #   confirmation_template_id:    custom confirmation template (used with double_opt_in: true)
      #   subscriber:                  { first_name:, last_name: } — populates Subscriber on first send
      # rubocop:disable Metrics/ParameterLists -- mirrors the API's flat param surface
      def create(to:, subject: nil, body: nil, reply_to: nil, preheader: nil,
                 template_id: nil, include_unsubscribe_link: nil,
                 double_opt_in: nil, confirmation_template_id: nil,
                 subscriber: nil, **extra)
        # rubocop:enable Metrics/ParameterLists
        payload = { to: to }
        payload[:subject] = subject unless subject.nil?
        payload[:body] = body unless body.nil?
        payload[:preheader] = preheader unless preheader.nil?
        payload[:reply_to] = reply_to unless reply_to.nil?
        payload[:template_id] = template_id unless template_id.nil?
        payload[:include_unsubscribe_link] = include_unsubscribe_link unless include_unsubscribe_link.nil?
        payload[:double_opt_in] = double_opt_in unless double_opt_in.nil?
        payload[:confirmation_template_id] = confirmation_template_id unless confirmation_template_id.nil?
        payload[:subscriber] = subscriber unless subscriber.nil?
        payload.merge!(extra) unless extra.empty?

        post('/api/v1/transactionals.json', payload)
      end

      def get_transactional(id)
        get("/api/v1/transactionals/#{id}.json")
      end
    end
  end
end
