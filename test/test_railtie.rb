# frozen_string_literal: true

require 'test_helper'
require 'action_mailer'
require 'broadcast/delivery_method'

# Register the delivery method the same way the Railtie would
ActionMailer::Base.add_delivery_method :broadcast, Broadcast::DeliveryMethod

class TestRailtie < Minitest::Test
  def test_registers_broadcast_settings
    assert ActionMailer::Base.respond_to?(:broadcast_settings=),
           'Expected ActionMailer::Base to accept broadcast_settings'
  end

  def test_broadcast_is_valid_delivery_method
    ActionMailer::Base.delivery_method = :broadcast
    ActionMailer::Base.broadcast_settings = { api_token: 'tok', host: HOST }

    assert_equal :broadcast, ActionMailer::Base.delivery_method
  end

  def test_railtie_class_loads
    require 'rails/railtie'
    require 'broadcast/railtie'
    assert defined?(Broadcast::Railtie)
    assert Broadcast::Railtie < Rails::Railtie
  rescue LoadError
    skip 'Rails not available'
  end
end
