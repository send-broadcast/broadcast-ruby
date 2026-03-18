# frozen_string_literal: true

require 'test_helper'
require 'logger'

class TestClient < Minitest::Test
  # --- Constructor ---

  def test_validates_config_on_init
    assert_raises(Broadcast::ConfigurationError) { Broadcast::Client.new(api_token: nil) }
  end

  def test_rejects_empty_token
    assert_raises(Broadcast::ConfigurationError) { Broadcast::Client.new(api_token: '  ') }
  end

  def test_accepts_valid_settings
    client = new_client
    assert_equal 'test-token', client.config.api_token
    assert_equal HOST, client.config.host
  end

  def test_trailing_slash_stripped_from_host
    client = Broadcast::Client.new(api_token: 'tok', host: 'https://example.com/')
    assert_equal 'https://example.com', client.config.host
  end

  # --- Transactional email ---

  def test_send_email
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(
        headers: { 'Authorization' => 'Bearer test-token' },
        body: hash_including('to' => 'user@example.com', 'subject' => 'Hello', 'body' => '<p>Hi</p>')
      )
      .to_return(status: 200, body: { id: 42 }.to_json)

    result = new_client.send_email(to: 'user@example.com', subject: 'Hello', body: '<p>Hi</p>')
    assert_equal 42, result['id']
  end

  def test_send_email_with_reply_to
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('reply_to' => 'reply@example.com'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x', reply_to: 'reply@example.com')
  end

  def test_send_email_omits_nil_reply_to
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      !JSON.parse(req.body).key?('reply_to')
    end
  end

  def test_get_email
    stub_request(:get, "#{HOST}/api/v1/transactionals/42.json")
      .to_return(status: 200, body: { id: 42, status: 'sent' }.to_json)

    result = new_client.get_email(42)
    assert_equal 'sent', result['status']
  end

  # --- Error handling ---

  def test_authentication_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 401, body: { error: 'Invalid token' }.to_json)

    error = assert_raises(Broadcast::AuthenticationError) do
      new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    end
    assert_match(/Invalid token/, error.message)
  end

  def test_not_found_error
    stub_request(:get, "#{HOST}/api/v1/transactionals/999.json")
      .to_return(status: 404, body: { error: 'Not found' }.to_json)

    assert_raises(Broadcast::NotFoundError) { new_client.get_email(999) }
  end

  def test_validation_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 422, body: { error: 'to is required' }.to_json)

    assert_raises(Broadcast::ValidationError) do
      new_client.send_email(to: '', subject: 'Hi', body: 'x')
    end
  end

  def test_rate_limit_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json)

    assert_raises(Broadcast::RateLimitError) do
      new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    end
  end

  def test_server_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 500, body: { error: 'Internal server error' }.to_json)

    assert_raises(Broadcast::APIError) do
      new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    end
  end

  def test_timeout_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json").to_timeout

    assert_raises(Broadcast::TimeoutError) do
      new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    end
  end

  def test_empty_response_body
    stub_request(:delete, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: '')

    result = new_client.request(:delete, '/api/v1/sequences/1')
    assert_equal({}, result)
  end

  # --- Retry ---

  def test_retries_on_server_error
    client = new_client(retry_attempts: 3, retry_delay: 0)

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return({ status: 500, body: { error: 'Server error (500)' }.to_json })
      .then.to_return({ status: 200, body: { id: 1 }.to_json })

    result = client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    assert_equal 1, result['id']
  end

  def test_retries_on_timeout
    client = new_client(retry_attempts: 3, retry_delay: 0)

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_timeout
      .then.to_return({ status: 200, body: { id: 1 }.to_json })

    result = client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    assert_equal 1, result['id']
  end

  def test_does_not_retry_client_errors
    client = new_client(retry_attempts: 3, retry_delay: 0)

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 422, body: { error: 'Validation failed' }.to_json)

    assert_raises(Broadcast::ValidationError) do
      client.send_email(to: '', subject: 'Hi', body: 'x')
    end
    assert_requested(:post, "#{HOST}/api/v1/transactionals.json", times: 1)
  end

  # --- Sub-clients ---

  def test_resource_sub_clients
    client = new_client
    assert_instance_of Broadcast::Resources::Subscribers, client.subscribers
    assert_instance_of Broadcast::Resources::Sequences, client.sequences
    assert_instance_of Broadcast::Resources::Broadcasts, client.broadcasts
    assert_instance_of Broadcast::Resources::Segments, client.segments
    assert_instance_of Broadcast::Resources::Templates, client.templates
    assert_instance_of Broadcast::Resources::WebhookEndpoints, client.webhook_endpoints
  end

  def test_sub_clients_memoized
    client = new_client
    assert_same client.subscribers, client.subscribers
  end

  # --- Query params ---

  def test_get_with_params
    stub_request(:get, "#{HOST}/api/v1/subscribers.json?page=2&is_active=true")
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    new_client.request(:get, '/api/v1/subscribers.json', { page: 2, is_active: true })
  end

  def test_get_with_array_params
    stub_request(:get, "#{HOST}/api/v1/subscribers.json?tags%5B%5D=a&tags%5B%5D=b")
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    new_client.request(:get, '/api/v1/subscribers.json', { tags: %w[a b] })
  end

  def test_get_with_boolean_false
    stub_request(:get, "#{HOST}/api/v1/subscribers.json?is_active=false")
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    new_client.request(:get, '/api/v1/subscribers.json', { is_active: false })
  end

  def test_get_skips_nil_params
    stub_request(:get, "#{HOST}/api/v1/subscribers.json?page=1")
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    new_client.request(:get, '/api/v1/subscribers.json', { page: 1, email: nil })
  end

  # --- HTTP method verification ---

  def test_delete_uses_delete_method
    stub_request(:delete, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: {}.to_json)

    new_client.request(:delete, '/api/v1/sequences/1')
    assert_requested(:delete, "#{HOST}/api/v1/sequences/1")
  end

  def test_patch_uses_patch_method
    stub_request(:patch, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: {}.to_json)

    new_client.request(:patch, '/api/v1/sequences/1', { label: 'x' })
    assert_requested(:patch, "#{HOST}/api/v1/sequences/1")
  end

  # --- User-Agent ---

  def test_sends_user_agent_header
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(headers: { 'User-Agent' => "broadcast-ruby/#{Broadcast::VERSION}" })
      .to_return(status: 200, body: { id: 1 }.to_json)

    new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
  end

  # --- Debug logging ---

  def test_debug_logging
    log_output = StringIO.new
    client = new_client(debug: true, logger: Logger.new(log_output))

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    assert_includes log_output.string, 'Broadcast'
    assert_includes log_output.string, 'POST'
    assert_includes log_output.string, 'Response: 200'
  end
end
