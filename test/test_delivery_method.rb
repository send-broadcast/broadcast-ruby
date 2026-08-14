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

  # --- Host resolution ---

  def test_requires_host
    with_env(Broadcast::Configuration::ENV_HOST => nil) do
      assert_raises(Broadcast::ConfigurationError) { Broadcast::DeliveryMethod.new(api_token: 'tok') }
    end
  end

  def test_falls_back_to_env_host
    dm = with_env(Broadcast::Configuration::ENV_HOST => HOST) do
      Broadcast::DeliveryMethod.new(api_token: 'tok')
    end

    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    dm.deliver!(mail)
    assert_requested(:post, "#{HOST}/api/v1/transactionals.json")
  end

  # A raised warning means the send happened but a parameter was ignored —
  # it must not be reported to ActionMailer as a delivery failure.
  def test_warning_error_is_not_wrapped_as_delivery_error
    dm = Broadcast::DeliveryMethod.new(api_token: 'tok', host: HOST, warnings_mode: :raise)

    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 201,
                 body: { id: 1, warnings: [{ code: 'parameter_ignored', message: 'ignored' }] }.to_json)

    assert_raises(Broadcast::WarningError) { dm.deliver!(mail) }
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

  # --- HTML flagging (regression: nested HTML documents) ---
  #
  # Reproduces a real delivered message. deliver! sent an HTML body without
  # telling Broadcast it was HTML, so Broadcast recorded the send as plain text
  # and wrapped the payload in its own <html><body> shell. The delivered part
  # then contained two nested complete HTML documents. Gmail tolerated it;
  # Outlook is far less forgiving, and it is malformed either way.

  def test_flags_html_body_when_the_mail_has_an_html_part
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      html_part { body '<p>Hi there</p>' }
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('html_body' => true))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  def test_does_not_flag_html_body_for_plain_text_mail
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Plain text'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with { |req| !JSON.parse(req.body).fetch('html_body', false) }
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  # --- Unsubscribe suppression (regression: unsubscribe on a password reset) ---
  #
  # Reproduces a real delivered message. A password reset arrived carrying
  # List-Unsubscribe and List-Unsubscribe-Post: One-Click, because deliver!
  # could not say "this is transactional" and the channel's unsubscribe setting
  # applied to it. Clicking it marks the person unsubscribed, silently excluding
  # them from every sequence and broadcast — from a click on a security email.

  def test_suppresses_the_unsubscribe_link_by_default
    mail = Mail.new do
      to 'user@example.com'
      subject 'Reset your password'
      body 'Reset link'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('include_unsubscribe_link' => false))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @dm.deliver!(mail)
  end

  def test_unsubscribe_link_can_be_opted_back_in_via_settings
    dm = Broadcast::DeliveryMethod.new(@settings.merge(include_unsubscribe_link: true))
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('include_unsubscribe_link' => true))
      .to_return(status: 200, body: { id: 1 }.to_json)

    dm.deliver!(mail)
  end

  # Intent: the option is consumed by the delivery method, not forwarded into
  # Client, whose Configuration would reject an unknown key.
  def test_settings_option_does_not_leak_into_the_client
    mail = Mail.new do
      to 'user@example.com'
      subject 'Hello'
      body 'Hi'
    end

    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 200, body: { id: 1 }.to_json)

    # Constructing is the assertion: Configuration#include_unsubscribe_link= does
    # not exist, so a leak raises NoMethodError here.
    dm = Broadcast::DeliveryMethod.new(@settings.merge(include_unsubscribe_link: false))
    assert_instance_of Broadcast::DeliveryMethod, dm
    dm.deliver!(mail)
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
