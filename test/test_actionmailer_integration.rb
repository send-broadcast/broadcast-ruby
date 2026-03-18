# frozen_string_literal: true

require 'test_helper'
require 'action_mailer'
require 'broadcast/delivery_method'

# Register delivery method as the Railtie would
ActionMailer::Base.add_delivery_method :broadcast, Broadcast::DeliveryMethod

# A real mailer class
class TestAppMailer < ActionMailer::Base
  self.delivery_method = :broadcast
  self.broadcast_settings = { api_token: 'test-token', host: HOST }

  default from: 'app@example.com'

  def welcome(email)
    mail(
      to: email,
      subject: 'Welcome to TestApp'
    ) do |format|
      format.html { render plain: '<h1>Welcome!</h1><p>Thanks for signing up.</p>' }
      format.text { render plain: 'Welcome! Thanks for signing up.' }
    end
  end

  def plain_text_only(email)
    mail(
      to: email,
      subject: 'Plain text email'
    ) do |format|
      format.text { render plain: 'No HTML here.' }
    end
  end

  def with_reply_to(email)
    mail(
      to: email,
      subject: 'Has reply-to',
      reply_to: 'support@example.com'
    ) do |format|
      format.html { render plain: '<p>Contact support</p>' }
    end
  end
end

class TestActionMailerIntegration < Minitest::Test
  def test_deliver_now_sends_via_broadcast_api
    stub = stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(
        headers: { 'Authorization' => 'Bearer test-token' },
        body: hash_including(
          'to' => 'user@example.com',
          'subject' => 'Welcome to TestApp'
        )
      )
      .to_return(status: 200, body: { id: 1 }.to_json)

    TestAppMailer.welcome('user@example.com').deliver_now

    assert_requested(stub)
  end

  def test_delivers_html_body
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    TestAppMailer.welcome('user@example.com').deliver_now

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      body = JSON.parse(req.body)
      body['body'].include?('<h1>Welcome!</h1>')
    end
  end

  def test_falls_back_to_text_when_no_html
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    TestAppMailer.plain_text_only('user@example.com').deliver_now

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      body = JSON.parse(req.body)
      body['body'].include?('No HTML here.')
    end
  end

  def test_includes_reply_to
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('reply_to' => 'support@example.com'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    TestAppMailer.with_reply_to('user@example.com').deliver_now
  end

  def test_api_failure_raises_delivery_error
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

    assert_raises(Broadcast::DeliveryError) do
      TestAppMailer.welcome('user@example.com').deliver_now
    end
  end
end
