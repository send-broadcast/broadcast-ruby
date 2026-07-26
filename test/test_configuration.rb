# frozen_string_literal: true

require 'test_helper'

class TestConfiguration < Minitest::Test
  def test_defaults
    config = with_env(Broadcast::Configuration::ENV_HOST => nil,
                      Broadcast::Configuration::ENV_TOKEN => nil) do
      Broadcast::Configuration.new
    end

    assert_nil config.host, 'there is no correct default host for a self-hosted-first product'
    assert_equal 30, config.timeout
    assert_equal 10, config.open_timeout
    assert_equal 3, config.retry_attempts
    assert_equal 1, config.retry_delay
    assert_equal 30, config.max_retry_delay
    assert_equal :log, config.warnings_mode
    assert_equal false, config.debug
    assert_nil config.api_token
    assert_nil config.logger
    assert_nil config.broadcast_channel_id
  end

  def test_custom_host
    config = Broadcast::Configuration.new
    config.host = 'https://broadcast.mycompany.com'
    assert_equal 'https://broadcast.mycompany.com', config.host
  end

  # --- Validation ---

  def test_validate_requires_api_token
    config = new_config(api_token: nil)
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_rejects_empty_string
    config = new_config(api_token: '')
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_rejects_whitespace
    config = new_config(api_token: '   ')
    assert_raises(Broadcast::ConfigurationError) { config.validate! }
  end

  def test_validate_passes_with_token_and_host
    config = new_config(api_token: 'valid-token', host: HOST)
    config.validate!
  end

  # --- Host is required (breaking change in 0.3.0) ---

  def test_validate_requires_host
    config = new_config(api_token: 'valid-token', host: nil)
    error = assert_raises(Broadcast::ConfigurationError) { config.validate! }
    assert_match(/host is required/, error.message)
  end

  def test_host_error_names_the_env_var
    config = new_config(api_token: 'valid-token', host: nil)
    error = assert_raises(Broadcast::ConfigurationError) { config.validate! }
    assert_match(/BROADCAST_HOST/, error.message)
  end

  def test_validate_rejects_host_without_scheme
    config = new_config(api_token: 'valid-token', host: 'mail.example.com')
    error = assert_raises(Broadcast::ConfigurationError) { config.validate! }
    assert_match(/must include a scheme/, error.message)
  end

  def test_validate_strips_trailing_slash_from_host
    config = new_config(api_token: 'valid-token', host: 'https://mail.example.com/')
    config.validate!
    assert_equal 'https://mail.example.com', config.host
  end

  def test_validate_leaves_clean_host_alone
    config = new_config(api_token: 'valid-token', host: 'https://mail.example.com')
    config.validate!
    assert_equal 'https://mail.example.com', config.host
  end

  def test_validate_strips_surrounding_whitespace_from_host
    config = new_config(api_token: 'valid-token', host: '  https://mail.example.com  ')
    config.validate!
    assert_equal 'https://mail.example.com', config.host
  end

  # --- Env fallbacks ---

  def test_reads_host_and_token_from_env
    config = with_env(Broadcast::Configuration::ENV_HOST => 'https://env.example.com',
                      Broadcast::Configuration::ENV_TOKEN => 'env-token') do
      Broadcast::Configuration.new
    end

    assert_equal 'https://env.example.com', config.host
    assert_equal 'env-token', config.api_token
  end

  def test_explicit_settings_win_over_env
    client = with_env(Broadcast::Configuration::ENV_HOST => 'https://env.example.com',
                      Broadcast::Configuration::ENV_TOKEN => 'env-token') do
      Broadcast::Client.new(api_token: 'explicit', host: 'https://explicit.example.com')
    end

    assert_equal 'https://explicit.example.com', client.config.host
    assert_equal 'explicit', client.config.api_token
  end

  def test_client_boots_from_env_alone
    client = with_env(Broadcast::Configuration::ENV_HOST => 'https://env.example.com',
                      Broadcast::Configuration::ENV_TOKEN => 'env-token') do
      Broadcast::Client.new
    end

    assert_equal 'https://env.example.com', client.config.host
  end

  # --- warnings_mode ---

  def test_warnings_mode_accepts_valid_values
    %i[log raise ignore].each do |mode|
      config = new_config(api_token: 'tok', host: HOST)
      config.warnings_mode = mode
      config.validate!
      assert_equal mode, config.warnings_mode
    end
  end

  def test_warnings_mode_coerces_string
    config = new_config(api_token: 'tok', host: HOST)
    config.warnings_mode = 'raise'
    config.validate!
    assert_equal :raise, config.warnings_mode
  end

  def test_warnings_mode_rejects_unknown_value
    config = new_config(api_token: 'tok', host: HOST)
    config.warnings_mode = :explode
    error = assert_raises(Broadcast::ConfigurationError) { config.validate! }
    assert_match(/warnings_mode must be one of/, error.message)
  end

  private

  # Builds a config with the environment neutralised, so a developer machine
  # with BROADCAST_HOST exported can't mask a validation test.
  def new_config(api_token: nil, host: nil)
    config = with_env(Broadcast::Configuration::ENV_HOST => nil,
                      Broadcast::Configuration::ENV_TOKEN => nil) do
      Broadcast::Configuration.new
    end
    config.api_token = api_token
    config.host = host
    config
  end
end
