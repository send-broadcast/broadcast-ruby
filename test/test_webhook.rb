# frozen_string_literal: true

require 'test_helper'

class TestWebhook < Minitest::Test
  SECRET = 'whsec_test_secret_key'

  def test_verify_valid_signature
    payload = '{"type":"email.sent"}'
    now = Time.now
    timestamp = now.to_i.to_s
    sig = sign(payload, timestamp)

    assert Broadcast::Webhook.verify(payload, "v1,#{sig}", timestamp, secret: SECRET, now: now)
  end

  def test_verify_invalid_signature
    now = Time.now
    refute Broadcast::Webhook.verify('payload', 'v1,bad==', now.to_i.to_s, secret: SECRET, now: now)
  end

  def test_verify_tampered_payload
    payload = '{"type":"email.sent"}'
    now = Time.now
    timestamp = now.to_i.to_s
    sig = sign(payload, timestamp)

    refute Broadcast::Webhook.verify('{"hacked":true}', "v1,#{sig}", timestamp, secret: SECRET, now: now)
  end

  def test_verify_wrong_secret
    payload = '{"type":"email.sent"}'
    now = Time.now
    timestamp = now.to_i.to_s
    sig = sign(payload, timestamp)

    refute Broadcast::Webhook.verify(payload, "v1,#{sig}", timestamp, secret: 'wrong', now: now)
  end

  def test_verify_expired_timestamp
    payload = '{"type":"email.sent"}'
    now = Time.now
    old = (now.to_i - 600).to_s
    sig = sign(payload, old)

    refute Broadcast::Webhook.verify(payload, "v1,#{sig}", old, secret: SECRET, now: now)
  end

  def test_verify_within_tolerance
    payload = '{"type":"email.sent"}'
    now = Time.now
    ts = (now.to_i - 299).to_s
    sig = sign(payload, ts)

    assert Broadcast::Webhook.verify(payload, "v1,#{sig}", ts, secret: SECRET, now: now)
  end

  def test_verify_outside_tolerance
    payload = '{"type":"email.sent"}'
    now = Time.now
    ts = (now.to_i - 301).to_s
    sig = sign(payload, ts)

    refute Broadcast::Webhook.verify(payload, "v1,#{sig}", ts, secret: SECRET, now: now)
  end

  def test_verify_nil_inputs
    refute Broadcast::Webhook.verify(nil, 'v1,sig', '123', secret: SECRET)
    refute Broadcast::Webhook.verify('x', nil, '123', secret: SECRET)
    refute Broadcast::Webhook.verify('x', 'v1,sig', nil, secret: SECRET)
    refute Broadcast::Webhook.verify('x', 'v1,sig', '123', secret: nil)
  end

  def test_verify_wrong_signature_format
    refute Broadcast::Webhook.verify('x', 'nosigprefix', Time.now.to_i.to_s, secret: SECRET, now: Time.now)
  end

  def test_verify_empty_signature_after_prefix
    refute Broadcast::Webhook.verify('x', 'v1,', Time.now.to_i.to_s, secret: SECRET, now: Time.now)
  end

  def test_compute_signature_deterministic
    sig1 = Broadcast::Webhook.compute_signature('payload', 123, SECRET)
    sig2 = Broadcast::Webhook.compute_signature('payload', 123, SECRET)
    assert_equal sig1, sig2
  end

  def test_compute_signature_differs_for_different_inputs
    sig1 = Broadcast::Webhook.compute_signature('a', 123, SECRET)
    sig2 = Broadcast::Webhook.compute_signature('b', 123, SECRET)
    refute_equal sig1, sig2
  end

  def test_compute_signature_is_base64
    sig = Broadcast::Webhook.compute_signature('payload', 123, SECRET)
    Base64.strict_decode64(sig) # raises on invalid base64
  end

  private

  def sign(payload, timestamp)
    hmac = OpenSSL::HMAC.digest('SHA256', SECRET, "#{timestamp}.#{payload}")
    Base64.strict_encode64(hmac)
  end
end
