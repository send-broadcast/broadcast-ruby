# frozen_string_literal: true

require 'test_helper'

class TestDiscovery < Minitest::Test
  def setup
    @client = new_client
  end

  def test_whoami
    stub_request(:get, "#{HOST}/api/v1/whoami")
      .to_return(status: 200, body: {
        token: { label: 'CI', type: 'channel_scoped', permissions: { subscribers: %w[read write] } },
        channel: { id: 1, name: 'Main', slug: 'main' }
      }.to_json)

    result = @client.whoami
    assert_equal 'channel_scoped', result['token']['type']
    assert_equal 'Main', result['channel']['name']
  end

  def test_status
    stub_request(:get, "#{HOST}/api/v1/status")
      .to_return(status: 200, body: {
        channel: { name: 'Main', sender_email: 'hi@example.com' },
        subscribers: { total: 10, active: 8 },
        readiness: { broadcasts: true, sequences: false, transactionals: true }
      }.to_json)

    result = @client.status
    assert_equal 8, result['subscribers']['active']
    assert_equal false, result['readiness']['sequences']
  end

  def test_prime
    stub_request(:get, "#{HOST}/api/v1/prime")
      .to_return(status: 200, body: {
        platform: { name: 'Broadcast', version: '2.19.0' },
        capabilities: [{ resource: 'subscribers' }],
        rate_limit: { requests_per_minute: 120 }
      }.to_json)

    result = @client.prime
    assert_equal '2.19.0', result['platform']['version']
    assert_equal 120, result['rate_limit']['requests_per_minute']
  end

  # /api/v1/skill serves text/plain, so it must bypass JSON parsing entirely.
  def test_skill_returns_plain_text
    body = "---\nname: broadcast\n---\n\n# Broadcast Email Marketing Skill\n"
    stub_request(:get, "#{HOST}/api/v1/skill")
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'text/plain' })

    assert_equal body, @client.skill
  end

  def test_skill_errors_still_raise
    stub_request(:get, "#{HOST}/api/v1/skill")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

    assert_raises(Broadcast::AuthenticationError) { @client.skill }
  end

  # /api/v1/openapi serves application/yaml, so like #skill it must bypass JSON
  # parsing and come back as a String.
  def test_openapi_returns_the_yaml_document
    body = "openapi: 3.1.0\ninfo:\n  title: Broadcast API\n"
    stub_request(:get, "#{HOST}/api/v1/openapi")
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/yaml; charset=utf-8' })

    assert_equal body, @client.openapi
  end

  def test_openapi_errors_still_raise
    stub_request(:get, "#{HOST}/api/v1/openapi")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

    assert_raises(Broadcast::AuthenticationError) { @client.openapi }
  end

  def test_discovery_sub_client_is_memoized
    assert_same @client.discovery, @client.discovery
    assert_instance_of Broadcast::Resources::Discovery, @client.discovery
  end

  def test_channel_scope_is_applied
    stub_request(:get, %r{#{HOST}/api/v1/whoami.*broadcast_channel_id=42})
      .to_return(status: 200, body: {}.to_json)

    client = new_client(broadcast_channel_id: 42)
    client.whoami

    assert_requested(:get, /broadcast_channel_id=42/)
  end
end
