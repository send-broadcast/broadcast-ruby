# frozen_string_literal: true

require 'action_mailer'
require_relative 'delivery_method'

module Broadcast
  class Railtie < Rails::Railtie
    # Register the delivery method at class load time so that
    # broadcast_settings= exists before environment configs run.
    ActionMailer::Base.add_delivery_method :broadcast, Broadcast::DeliveryMethod
  end
end
