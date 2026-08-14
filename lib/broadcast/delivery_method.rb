# frozen_string_literal: true

module Broadcast
  class DeliveryMethod
    # ActionMailer delivers transactional mail, so the unsubscribe link is off
    # unless the host app opts back in via broadcast_settings. The option is
    # consumed here rather than forwarded: Configuration would reject it.
    DEFAULT_INCLUDE_UNSUBSCRIBE_LINK = false

    def initialize(settings = {})
      opts = settings.to_h.dup
      @include_unsubscribe_link =
        if opts.key?(:include_unsubscribe_link)
          opts.delete(:include_unsubscribe_link)
        else
          DEFAULT_INCLUDE_UNSUBSCRIBE_LINK
        end

      @client = Client.new(**opts)
    end

    def deliver!(mail)
      @client.send_email(
        to: mail.to&.first,
        subject: mail.subject,
        body: extract_body(mail),
        reply_to: mail.reply_to&.first,
        html_body: (true if mail.html_part),
        include_unsubscribe_link: @include_unsubscribe_link
      )
    rescue Broadcast::WarningError
      # The send succeeded — warnings_mode: :raise is about surfacing ignored
      # parameters, not reporting a delivery failure. Wrapping it in
      # DeliveryError would tell ActionMailer the mail didn't go out.
      raise
    rescue Broadcast::Error => e
      raise DeliveryError, "Failed to deliver email: #{e.message}"
    end

    private

    def extract_body(mail)
      if mail.html_part
        mail.html_part.body.to_s
      elsif mail.text_part
        mail.text_part.body.to_s
      else
        mail.body.to_s
      end
    end
  end
end
