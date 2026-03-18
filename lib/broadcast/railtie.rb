# frozen_string_literal: true

require_relative 'delivery_method'

module Broadcast
  class Railtie < Rails::Railtie
    initializer 'broadcast.add_delivery_method', before: :load_config_initializers do
      ActionMailer::Base.add_delivery_method :broadcast, Broadcast::DeliveryMethod
    end
  end
end
