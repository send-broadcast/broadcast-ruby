# frozen_string_literal: true

# Live integration tests against a real Broadcast instance.
#
# Usage:
#   BROADCAST_API_TOKEN=your-token BROADCAST_HOST=https://sendbroadcast.com bundle exec rake test_live
#
# Optional:
#   BROADCAST_TEST_EMAIL=you@example.com  — recipient for transactional email test (default: skips send)
#
# These tests create and clean up real data. Use a test/staging channel, not production.

require 'minitest/autorun'
require 'securerandom'
require 'logger'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'broadcast'

LIVE_TOKEN = ENV.fetch('BROADCAST_API_TOKEN', nil)
LIVE_HOST = ENV.fetch('BROADCAST_HOST', nil)
LIVE_ENABLED = LIVE_TOKEN && LIVE_HOST && !ENV['BROADCAST_SKIP_LIVE']

class TestLive < Minitest::Test
  def setup
    skip 'Set BROADCAST_API_TOKEN and BROADCAST_HOST to run live tests' unless LIVE_ENABLED

    @client = Broadcast::Client.new(
      api_token: LIVE_TOKEN,
      host: LIVE_HOST,
      debug: true,
      logger: Logger.new($stdout)
    )
  end

  # --- Connection ---

  def test_connection
    result = @client.subscribers.list(page: 1)
    assert result.key?('subscribers'), 'Expected subscribers key in response'
    assert result.key?('pagination'), 'Expected pagination key in response'
  end

  # --- Subscribers ---

  def test_subscriber_lifecycle
    email = "broadcast-ruby-test-#{SecureRandom.hex(4)}@example.com"

    # Create
    result = @client.subscribers.create(
      email: email,
      first_name: 'Test',
      last_name: 'User',
      tags: ['broadcast-ruby-test'],
      custom_data: { source: 'gem-test' }
    )
    assert result

    # Find
    subscriber = @client.subscribers.find(email: email)
    assert_equal email, subscriber['email']
    assert_equal 'Test', subscriber['first_name']
    assert_includes subscriber['tags'], 'broadcast-ruby-test'

    # Update
    @client.subscribers.update(email, first_name: 'Updated')
    subscriber = @client.subscribers.find(email: email)
    assert_equal 'Updated', subscriber['first_name']

    # Add tags
    @client.subscribers.add_tags(email, ['live-test-tag'])
    subscriber = @client.subscribers.find(email: email)
    assert_includes subscriber['tags'], 'live-test-tag'

    # Remove tags
    @client.subscribers.remove_tags(email, ['live-test-tag'])
    subscriber = @client.subscribers.find(email: email)
    refute_includes subscriber['tags'], 'live-test-tag'

    # Deactivate / Activate
    @client.subscribers.deactivate(email)
    subscriber = @client.subscribers.find(email: email)
    assert_equal false, subscriber['is_active']

    @client.subscribers.activate(email)
    subscriber = @client.subscribers.find(email: email)
    assert_equal true, subscriber['is_active']

    # Unsubscribe / Resubscribe
    @client.subscribers.unsubscribe(email)
    subscriber = @client.subscribers.find(email: email)
    assert_equal false, subscriber['is_active']
    refute_nil subscriber['unsubscribed_at']

    @client.subscribers.resubscribe(email)
    subscriber = @client.subscribers.find(email: email)
    assert_equal true, subscriber['is_active']
    assert_nil subscriber['unsubscribed_at']

    # Cleanup: redact
    result = @client.subscribers.redact(email)
    assert result['message']&.include?('redacted')
  end

  def test_subscriber_not_found
    assert_raises(Broadcast::NotFoundError) do
      @client.subscribers.find(email: "nonexistent-#{SecureRandom.hex(8)}@example.com")
    end
  end

  # --- Transactional Email ---

  def test_send_email
    test_email = ENV.fetch('BROADCAST_TEST_EMAIL', nil)
    skip 'Set BROADCAST_TEST_EMAIL to test transactional email delivery' unless test_email

    result = @client.send_email(
      to: test_email,
      subject: "broadcast-ruby gem test #{Time.now.strftime('%H:%M:%S')}",
      body: '<p>This is a live test from the broadcast-ruby gem test suite.</p>',
      reply_to: test_email
    )

    assert result['id'], 'Expected id in send_email response'

    # Verify we can retrieve it
    email = @client.get_email(result['id'])
    assert_equal test_email, email['recipient_email']
  end

  # --- Sequences ---

  def test_sequence_lifecycle
    # Create
    result = @client.sequences.create(
      label: "broadcast-ruby-test-#{SecureRandom.hex(4)}",
      active: false,
      track_opens: true,
      track_clicks: true
    )
    seq_id = result['id']
    assert seq_id

    # List
    sequences = @client.sequences.list
    assert sequences.is_a?(Array) || sequences.is_a?(Hash)

    # Get
    sequence = @client.sequences.get_sequence(seq_id)
    assert_equal seq_id, sequence['id']

    # Get with steps
    sequence = @client.sequences.get_sequence(seq_id, include_steps: true)
    assert sequence.key?('id')

    # Update
    @client.sequences.update(seq_id, label: 'updated-test-sequence')
    sequence = @client.sequences.get_sequence(seq_id)
    assert_equal 'updated-test-sequence', sequence['label']

    # Cleanup
    @client.sequences.delete(seq_id)

    assert_raises(Broadcast::NotFoundError) do
      @client.sequences.get_sequence(seq_id)
    end
  end

  # --- Segments ---

  def test_segment_lifecycle
    # Create
    result = @client.segments.create(
      name: "broadcast-ruby-test-#{SecureRandom.hex(4)}",
      description: 'Created by gem test suite',
      segment_groups_attributes: [
        {
          match_type: 'all',
          segment_rules_attributes: [
            { field: 'email', operator: 'contains', value: 'example.com',
              rule_type: 'text', value_type: 'string' }
          ]
        }
      ]
    )
    seg_id = result['id']
    assert seg_id

    # Get
    segment = @client.segments.get_segment(seg_id)
    assert segment

    # Update
    @client.segments.update(seg_id, name: 'updated-test-segment')

    # Cleanup
    @client.segments.delete(seg_id)
  end

  # --- Templates ---

  def test_template_lifecycle
    label = "broadcast-ruby-test-#{SecureRandom.hex(4)}"

    # Create
    result = @client.templates.create(
      label: label,
      subject: 'Test Subject {{first_name}}',
      body: '<p>Hello {{first_name}}</p>',
      html_body: true
    )
    tpl_id = result['id']
    assert tpl_id

    # Get
    template = @client.templates.get_template(tpl_id)
    assert_equal label, template['label']

    # Update
    @client.templates.update(tpl_id, subject: 'Updated Subject')
    template = @client.templates.get_template(tpl_id)
    assert_equal 'Updated Subject', template['subject']

    # List
    templates = @client.templates.list
    assert templates

    # Cleanup
    @client.templates.delete(tpl_id)
  end

  # --- Webhook Endpoints ---

  def test_webhook_endpoint_lifecycle
    # Create
    result = @client.webhook_endpoints.create(
      url: "https://example.com/webhooks/broadcast-ruby-test-#{SecureRandom.hex(4)}",
      event_types: ['email.sent', 'email.delivered'],
      description: 'Created by gem test suite',
      retries_to_attempt: 3
    )
    wh_id = result['id']
    assert wh_id
    assert result['secret'], 'Expected secret in create response'

    # Get
    endpoint = @client.webhook_endpoints.get_endpoint(wh_id)
    assert_equal wh_id, endpoint['id']

    # Update
    @client.webhook_endpoints.update(wh_id, active: false)
    endpoint = @client.webhook_endpoints.get_endpoint(wh_id)
    assert_equal false, endpoint['active']

    # Deliveries
    deliveries = @client.webhook_endpoints.deliveries(wh_id)
    assert deliveries

    # Cleanup
    @client.webhook_endpoints.delete(wh_id)
  end

  # --- Error handling ---

  def test_authentication_error
    bad_client = Broadcast::Client.new(api_token: 'invalid-token', host: LIVE_HOST)
    assert_raises(Broadcast::AuthenticationError) do
      bad_client.subscribers.list
    end
  end
end
