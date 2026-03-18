# frozen_string_literal: true

require 'test_helper'

class TestConfiguration < Minitest::Test
  def test_defaults
    config = Broadcast::Configuration.new
    assert_equal 'https://sendbroadcast.com', config.host
    assert_equal 30, config.timeout
    assert_equal 10, config.open_timeout
    assert_equal 3, config.retry_attempts
    assert_equal 1, config.retry_delay
    assert_equal false, config.debug
    assert_nil config.api_token
    assert_nil config.logger
  end

  def test_custom_host
    config = Broadcast::Configuration.new
    config.host = 'https://broadcast.mycompany.com'
    assert_equal 'https://broadcast.mycompany.com', config.host
  end

  def test_validate_requires_api_token
    config = Broadcast::Configuration.new
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_rejects_empty_string
    config = Broadcast::Configuration.new
    config.api_token = ''
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_rejects_whitespace
    config = Broadcast::Configuration.new
    config.api_token = '   '
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_passes_with_token
    config = Broadcast::Configuration.new
    config.api_token = 'valid-token'
    config.validate!
  end

  def test_validate_strips_trailing_slash_from_host
    config = Broadcast::Configuration.new
    config.api_token = 'valid-token'
    config.host = 'https://sendbroadcast.com/'
    config.validate!
    assert_equal 'https://sendbroadcast.com', config.host
  end

  def test_validate_leaves_clean_host_alone
    config = Broadcast::Configuration.new
    config.api_token = 'valid-token'
    config.host = 'https://sendbroadcast.com'
    config.validate!
    assert_equal 'https://sendbroadcast.com', config.host
  end
end
