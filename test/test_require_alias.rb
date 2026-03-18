# frozen_string_literal: true

require 'minitest/autorun'

class TestRequireAlias < Minitest::Test
  def test_require_broadcast_ruby_loads_broadcast_module
    # Simulate what Bundler does: require the gem name
    require 'broadcast-ruby'

    assert defined?(Broadcast), 'Expected Broadcast module to be defined'
    assert defined?(Broadcast::Client), 'Expected Broadcast::Client to be defined'
    assert defined?(Broadcast::Webhook), 'Expected Broadcast::Webhook to be defined'
  end

  def test_require_broadcast_also_works
    require 'broadcast'

    assert defined?(Broadcast), 'Expected Broadcast module to be defined'
  end
end
