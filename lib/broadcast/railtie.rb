# frozen_string_literal: true

require_relative 'delivery_method'

module Broadcast
  class Railtie < Rails::Railtie
    initializer 'broadcast.add_delivery_method' do
      ActiveSupport.on_load(:action_mailer) do
        ActionMailer::Base.add_delivery_method :broadcast, Broadcast::DeliveryMethod
      end
    end
  end
end
