# frozen_string_literal: true

require 'test_helper'
require 'logger'
require 'stringio'

class TestEmailServers < Minitest::Test
  def setup
    @servers = new_client.email_servers
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/email_servers")
      .to_return(status: 200, body: { data: [{ id: 1 }], total: 1 }.to_json)

    result = @servers.list
    assert_equal 1, result['total']
  end

  def test_list_with_pagination
    stub_request(:get, %r{#{HOST}/api/v1/email_servers})
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    @servers.list(limit: 10, offset: 20)
    assert_requested(:get, /limit=10/)
    assert_requested(:get, /offset=20/)
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { id: 3, label: 'SMTP' }.to_json)

    result = @servers.get_email_server(3)
    assert_equal 'SMTP', result['label']
  end

  def test_create_wraps_under_email_server
    stub_request(:post, "#{HOST}/api/v1/email_servers")
      .with(body: hash_including('email_server' => hash_including('label' => 'SES')))
      .to_return(status: 201, body: { id: 4 }.to_json)

    @servers.create(label: 'SES', vendor: 'aws_ses', delivery_method: 'aws_ses')
  end

  def test_update_wraps_under_email_server
    stub_request(:patch, "#{HOST}/api/v1/email_servers/3")
      .with(body: hash_including('email_server' => hash_including('label' => 'New')))
      .to_return(status: 200, body: { id: 3 }.to_json)

    @servers.update(3, label: 'New')
  end

  def test_update_strips_redacted_credentials
    stub_request(:patch, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { id: 3 }.to_json)

    # Build a redacted-looking response value (matches API redaction shape)
    redacted = 'abcd••••••••wxyz'

    @servers.update(3, label: 'Updated', smtp_password: redacted)

    assert_requested(:patch, "#{HOST}/api/v1/email_servers/3") do |req|
      es = JSON.parse(req.body)['email_server']
      es['label'] == 'Updated' && !es.key?('smtp_password')
    end
  end

  def test_update_keeps_real_credentials
    stub_request(:patch, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { id: 3 }.to_json)

    @servers.update(3, smtp_password: 'real-secret-value-here')

    assert_requested(:patch, "#{HOST}/api/v1/email_servers/3") do |req|
      JSON.parse(req.body)['email_server']['smtp_password'] == 'real-secret-value-here'
    end
  end

  def test_update_warns_via_logger_when_scrubbing
    stub_request(:patch, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { id: 3 }.to_json)

    log_output = StringIO.new
    client = new_client(logger: Logger.new(log_output))
    client.email_servers.update(3, smtp_password: '••••••••')

    assert_includes log_output.string, 'Dropped redacted smtp_password'
  end

  def test_update_strips_aws_secret_access_key
    stub_request(:patch, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { id: 3 }.to_json)

    @servers.update(3, aws_secret_access_key: '••••••••')

    assert_requested(:patch, "#{HOST}/api/v1/email_servers/3") do |req|
      es = JSON.parse(req.body)['email_server']
      !es.key?('aws_secret_access_key')
    end
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/email_servers/3")
      .to_return(status: 200, body: { message: 'Email server deleted successfully' }.to_json)

    result = @servers.delete(3)
    assert_includes result['message'], 'deleted'
  end

  def test_test_connection
    stub_request(:post, "#{HOST}/api/v1/email_servers/3/test_connection")
      .to_return(status: 200, body: { success: true, message: 'Connection successful' }.to_json)

    result = @servers.test_connection(3)
    assert_equal true, result['success']
  end

  def test_copy_to_channel
    stub_request(:post, "#{HOST}/api/v1/email_servers/3/copy_to_channel")
      .with(body: hash_including('target_channel_id' => 99))
      .to_return(status: 201, body: { id: 50 }.to_json)

    result = @servers.copy_to_channel(3, target_channel_id: 99)
    assert_equal 50, result['id']
  end

  def test_copy_to_channel_raises_authorization_error_when_forbidden
    stub_request(:post, "#{HOST}/api/v1/email_servers/3/copy_to_channel")
      .to_return(status: 403, body: { error: 'Admin API token required for cross-channel operations' }.to_json)

    assert_raises(Broadcast::AuthorizationError) do
      @servers.copy_to_channel(3, target_channel_id: 99)
    end
  end
end
