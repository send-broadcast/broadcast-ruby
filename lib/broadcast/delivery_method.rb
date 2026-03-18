# frozen_string_literal: true

module Broadcast
  class DeliveryMethod
    def initialize(settings = {})
      @client = Client.new(**settings)
    end

    def deliver!(mail)
      @client.send_email(
        to: mail.to&.first,
        subject: mail.subject,
        body: extract_body(mail),
        reply_to: mail.reply_to&.first
      )
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
