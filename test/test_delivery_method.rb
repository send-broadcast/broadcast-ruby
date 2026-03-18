# frozen_string_literal: true

require 'test_helper'
require 'mail'
require 'broadcast/delivery_method'

class TestDeliveryMethod < Minitest::Test
  def setup
    @settings = { api_token: 'test-token', host: HOST }
    @dm = Broadcast::DeliveryMethod.new(@settings)
  end

  # --- HTML email ---

  def test_delivers_html_email
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      html_part { body '<p>Hi there</p>' }
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(
        headers: { 'Authorization' => 'Bearer test-token' },
        body: hash_including('to' => 'user@example.com', 'subject' => 'Hello', 'body' => '<p>Hi there</p>')
      )
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Plain text fallback ---

  def test_delivers_plain_text_when_no_html
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Plain text'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('body' => 'Plain text'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Text part fallback ---

  def test_falls_back_to_text_part_when_no_html_part
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      text_part { body 'Text only' }
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('body' => 'Text only'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Prefers HTML over text ---

  def test_prefers_html_part_over_text_part
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      text_part { body 'Text version' }
      html_part { body '<p>HTML version</p>' }
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('body' => '<p>HTML version</p>'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Reply-to ---

  def test_includes_reply_to
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      reply_to 'reply@example.com'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('reply_to' => 'reply@example.com'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  def test_omits_reply_to_when_nil
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      !JSON.parse(req.body).key?('reply_to')
    end
  end

  # --- Multiple recipients ---

  def test_uses_first_recipient
    mail = Mail.new do
      to ['a@example.com', 'b@example.com']
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('to' => 'a@example.com'))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Default host ---

  def test_default_host
    dm = Broadcast::DeliveryMethod.new(api_token: 'tok')

    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, 'https://sendbroadcast.com/api/v1/transactionals.json')
      .to_return(status: 200, body: { id: 1 }.to_json)

    dm.deliver!(mail)
  end

  # --- Client reuse ---

  def test_reuses_client_across_delivers
    mail1 = Mail.new do
      to 'a@b.com'
      subject 'A'
      body '1'
    end

    mail2 = Mail.new do
      to 'c@d.com'
      subject 'B'
      body '2'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail1)
    @dm.deliver!(mail2)

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json", times: 2)
  end

  # --- Error wrapping ---

  def test_wraps_api_errors
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 401, body: { error: 'Bad token' }.to_json)

    error = assert_raises(Broadcast::DeliveryError) do
      @dm.deliver!(mail)
    end
    assert_match(/Failed to deliver email/, error.message)
    assert_match(/Bad token/, error.message)
  end
end
