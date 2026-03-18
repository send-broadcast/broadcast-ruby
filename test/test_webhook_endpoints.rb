# frozen_string_literal: true

require 'test_helper'

class TestWebhookEndpoints < Minitest::Test
  def setup
    @wh = new_client.webhook_endpoints
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/webhook_endpoints")
      .to_return(status: 200, body: { data: [{ id: 1 }] }.to_json)

    result = @wh.list
    assert_equal 1, result['data'].length
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/webhook_endpoints/1")
      .to_return(status: 200, body: { id: 1, url: 'https://app.com/hooks' }.to_json)

    result = @wh.get_endpoint(1)
    assert_equal 'https://app.com/hooks', result['url']
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/webhook_endpoints")
      .with(body: hash_including('webhook_endpoint' => hash_including('url' => 'https://app.com/hooks')))
      .to_return(status: 201, body: { id: 2, secret: 'whsec_abc' }.to_json)

    result = @wh.create(url: 'https://app.com/hooks', event_types: ['email.sent'])
    assert_equal 'whsec_abc', result['secret']
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/webhook_endpoints/1")
      .to_return(status: 200, body: { id: 1, active: false }.to_json)

    result = @wh.update(1, active: false)
    assert_equal false, result['active']
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/webhook_endpoints/1")
      .to_return(status: 200, body: {}.to_json)

    @wh.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/webhook_endpoints/1")
  end

  def test_send_test
    stub_request(:post, "#{HOST}/api/v1/webhook_endpoints/1/test")
      .with(body: hash_including('event_type' => 'email.delivered'))
      .to_return(status: 200, body: {}.to_json)

    @wh.test(1, event_type: 'email.delivered')
  end

  def test_deliveries
    stub_request(:get, "#{HOST}/api/v1/webhook_endpoints/1/deliveries?limit=10")
      .to_return(status: 200, body: { data: [] }.to_json)

    @wh.deliveries(1, limit: 10)
  end
end
