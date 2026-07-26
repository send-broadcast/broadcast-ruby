# frozen_string_literal: true

require 'test_helper'
require 'logger'

class TestConnection < Minitest::Test
  # --- Idempotency ---

  def test_sends_idempotency_key_header
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(headers: { 'Idempotency-Key' => 'order-123' })
      .to_return(status: 201, body: { id: 1 }.to_json)

    new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'order-123')
    assert_requested(:post, "#{HOST}/api/v1/transactionals.json")
  end

  def test_omits_idempotency_header_when_not_given
    stub_request(:post, "#{HOST}/api/v1/transactionals.json").to_return(status: 201, body: { id: 1 }.to_json)

    new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x')

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      !req.headers.key?('Idempotency-Key')
    end
  end

  def test_idempotency_key_is_not_sent_in_the_body
    stub_request(:post, "#{HOST}/api/v1/transactionals.json").to_return(status: 201, body: { id: 1 }.to_json)

    new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'k')

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      !JSON.parse(req.body).key?('idempotency_key')
    end
  end

  def test_rejects_overlong_idempotency_key
    error = assert_raises(ArgumentError) do
      new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'a' * 256)
    end
    assert_match(/255 characters or fewer/, error.message)
  end

  def test_blank_idempotency_key_is_dropped
    stub_request(:post, "#{HOST}/api/v1/transactionals.json").to_return(status: 201, body: { id: 1 }.to_json)

    new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: '   ')

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      !req.headers.key?('Idempotency-Key')
    end
  end

  def test_409_raises_conflict_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 409, body: { error: 'still being processed' }.to_json)

    error = assert_raises(Broadcast::ConflictError) do
      new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'k')
    end
    assert_match(/still being processed/, error.message)
  end

  def test_conflict_error_is_an_api_error
    assert_operator Broadcast::ConflictError, :<, Broadcast::APIError
  end

  def test_replayed_response_is_flagged
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 201, body: { id: 1 }.to_json, headers: { 'Idempotency-Replayed' => 'true' })

    result = new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'k')
    assert_predicate result, :idempotent_replay?
  end

  # --- Rate limiting ---

  def test_rate_limit_error_carries_retry_after
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json,
                 headers: { 'Retry-After' => '7' })

    error = assert_raises(Broadcast::RateLimitError) { new_client.broadcasts.get_broadcast(1) }
    assert_equal 7, error.retry_after
  end

  def test_retries_429_and_succeeds
    client = new_client(retry_attempts: 3, retry_delay: 0, max_retry_delay: 0)

    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json,
                 headers: { 'Retry-After' => '1' })
      .then.to_return(status: 200, body: { id: 1 }.to_json)

    assert_equal 1, client.broadcasts.get_broadcast(1)['id']
  end

  def test_gives_up_on_429_after_retry_attempts
    client = new_client(retry_attempts: 2, retry_delay: 0, max_retry_delay: 0)

    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json)

    assert_raises(Broadcast::RateLimitError) { client.broadcasts.get_broadcast(1) }
    assert_requested(:get, "#{HOST}/api/v1/broadcasts/1", times: 2)
  end

  def test_retry_after_is_capped_by_max_retry_delay
    connection = Broadcast::Connection.new(new_client(max_retry_delay: 5).config)
    error = Broadcast::RateLimitError.new('slow down', retry_after: 3600)

    assert_equal 5, connection.send(:rate_limit_delay, error, 1)
  end

  def test_falls_back_to_backoff_when_no_retry_after
    connection = Broadcast::Connection.new(new_client(retry_delay: 2, max_retry_delay: 30).config)
    error = Broadcast::RateLimitError.new('slow down')

    assert_equal 4, connection.send(:rate_limit_delay, error, 2)
  end

  # --- Redirects ---

  def test_follows_same_host_redirect_on_get
    stub_request(:get, "#{HOST}/api/v1/status")
      .to_return(status: 301, headers: { 'Location' => "#{HOST}/api/v2/status" })
    stub_request(:get, "#{HOST}/api/v2/status")
      .to_return(status: 200, body: { channel: { name: 'Main' } }.to_json)

    assert_equal 'Main', new_client.status['channel']['name']
  end

  # Every request carries Authorization: Bearer <token>. Following a redirect to
  # another host would hand the API token to whatever it points at.
  def test_refuses_cross_host_redirect
    stub_request(:get, "#{HOST}/api/v1/status")
      .to_return(status: 301, headers: { 'Location' => 'https://evil.test/api/v1/status' })

    error = assert_raises(Broadcast::APIError) { new_client.status }
    assert_match(/different host/, error.message)
    assert_match(/carries your API token/, error.message)
    refute_requested(:get, 'https://evil.test/api/v1/status')
  end

  def test_refuses_to_follow_redirect_on_write
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 301, headers: { 'Location' => 'https://moved.test/api/v1/transactionals.json' })

    error = assert_raises(Broadcast::APIError) do
      new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'x')
    end
    assert_match(%r{https://moved.test}, error.message)
    assert_match(/Set `host`/, error.message)
  end

  def test_redirect_without_location_raises
    stub_request(:get, "#{HOST}/api/v1/status").to_return(status: 302)

    error = assert_raises(Broadcast::APIError) { new_client.status }
    assert_match(/no Location header/, error.message)
  end

  def test_redirect_loop_is_bounded
    stub_request(:get, "#{HOST}/api/v1/status")
      .to_return(status: 301, headers: { 'Location' => "#{HOST}/api/v1/status" })

    error = assert_raises(Broadcast::APIError) { new_client.status }
    assert_match(/Too many redirects/, error.message)
  end

  def test_relative_redirect_location_is_resolved
    stub_request(:get, "#{HOST}/api/v1/status")
      .to_return(status: 308, headers: { 'Location' => '/api/v2/status' })
    stub_request(:get, "#{HOST}/api/v2/status").to_return(status: 200, body: { ok: true }.to_json)

    assert_equal true, new_client.status['ok']
  end

  # --- Error bodies ---

  def test_parses_activemodel_errors_hash
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 422, body: { errors: { recipient_email: ['is invalid'] } }.to_json)

    error = assert_raises(Broadcast::ValidationError) do
      new_client.send_email(to: 'nope', subject: 'Hi', body: 'x')
    end
    assert_match(/recipient_email is invalid/, error.message)
  end

  def test_success_covers_all_2xx
    stub_request(:delete, "#{HOST}/api/v1/templates/1").to_return(status: 204, body: '')
    assert_equal({}, new_client.templates.delete(1))
  end

  # --- Raw responses ---

  def test_raw_returns_string_body
    stub_request(:get, "#{HOST}/api/v1/skill")
      .to_return(status: 200, body: "---\nname: broadcast\n---\n# Skill",
                 headers: { 'Content-Type' => 'text/plain' })

    result = new_client.skill
    assert_kind_of String, result
    assert_match(/name: broadcast/, result)
  end

  # --- Debug logging ---

  def test_debug_log_redacts_credentials
    log = StringIO.new
    client = new_client(debug: true, logger: Logger.new(log))

    stub_request(:post, "#{HOST}/api/v1/email_servers").to_return(status: 201, body: { id: 1 }.to_json)

    client.email_servers.create(label: 'SMTP', smtp_password: 'hunter2', smtp_host: 'smtp.example.com')

    refute_includes log.string, 'hunter2'
    assert_includes log.string, '[REDACTED]'
    assert_includes log.string, 'smtp.example.com'
  end

  def test_custom_headers_do_not_clobber_defaults
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(headers: {
              'Authorization' => 'Bearer test-token',
              'User-Agent' => "broadcast-ruby/#{Broadcast::VERSION}",
              'Idempotency-Key' => 'k'
            })
      .to_return(status: 201, body: { id: 1 }.to_json)

    new_client.transactionals.create(to: 'a@b.com', subject: 'Hi', body: 'x', idempotency_key: 'k')
  end
end
