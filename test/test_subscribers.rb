# frozen_string_literal: true

require 'test_helper'

class TestSubscribers < Minitest::Test
  def setup
    @subs = new_client.subscribers
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/subscribers.json?page=1")
      .to_return(status: 200, body: { subscribers: [{ email: 'a@b.com' }] }.to_json)

    result = @subs.list(page: 1)
    assert_equal 1, result['subscribers'].length
  end

  def test_list_with_tags
    stub_request(:get, %r{#{HOST}/api/v1/subscribers\.json})
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    @subs.list(tags: %w[vip premium])
    assert_requested(:get, /tags/)
  end

  def test_find
    stub_request(:get, "#{HOST}/api/v1/subscribers/find.json?email=jane@example.com")
      .to_return(status: 200, body: { email: 'jane@example.com', tags: ['vip'] }.to_json)

    result = @subs.find(email: 'jane@example.com')
    assert_equal 'jane@example.com', result['email']
  end

  def test_find_not_found
    stub_request(:get, "#{HOST}/api/v1/subscribers/find.json?email=ghost@example.com")
      .to_return(status: 404, body: { error: 'Subscriber not found' }.to_json)

    assert_raises(Broadcast::NotFoundError) { @subs.find(email: 'ghost@example.com') }
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/subscribers.json")
      .with(body: hash_including('subscriber' => hash_including('email' => 'new@example.com')))
      .to_return(status: 201, body: { id: '123' }.to_json)

    @subs.create(email: 'new@example.com', first_name: 'Jane', tags: ['free'])
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/subscribers.json")
      .with(body: hash_including('email' => 'jane@example.com',
                                 'subscriber' => hash_including('first_name' => 'Janet')))
      .to_return(status: 200, body: { email: 'jane@example.com' }.to_json)

    @subs.update('jane@example.com', first_name: 'Janet')
  end

  def test_add_tags
    stub_request(:post, "#{HOST}/api/v1/subscribers/add_tag.json")
      .with(body: hash_including('email' => 'jane@example.com', 'tags' => ['vip']))
      .to_return(status: 200, body: {}.to_json)

    @subs.add_tags('jane@example.com', ['vip'])
  end

  def test_remove_tags
    stub_request(:delete, "#{HOST}/api/v1/subscribers/remove_tag.json")
      .with(body: hash_including('email' => 'jane@example.com', 'tags' => ['free']))
      .to_return(status: 200, body: {}.to_json)

    @subs.remove_tags('jane@example.com', ['free'])
    assert_requested(:delete, "#{HOST}/api/v1/subscribers/remove_tag.json")
  end

  def test_deactivate
    stub_request(:post, "#{HOST}/api/v1/subscribers/deactivate.json")
      .with(body: hash_including('email' => 'jane@example.com'))
      .to_return(status: 200, body: {}.to_json)

    @subs.deactivate('jane@example.com')
  end

  def test_activate
    stub_request(:post, "#{HOST}/api/v1/subscribers/activate.json")
      .with(body: hash_including('email' => 'jane@example.com'))
      .to_return(status: 200, body: {}.to_json)

    @subs.activate('jane@example.com')
  end

  def test_unsubscribe
    stub_request(:post, "#{HOST}/api/v1/subscribers/unsubscribe.json")
      .to_return(status: 200, body: { is_active: false }.to_json)

    result = @subs.unsubscribe('jane@example.com')
    assert_equal false, result['is_active']
  end

  def test_resubscribe
    stub_request(:post, "#{HOST}/api/v1/subscribers/resubscribe.json")
      .to_return(status: 200, body: { is_active: true }.to_json)

    result = @subs.resubscribe('jane@example.com')
    assert_equal true, result['is_active']
  end

  def test_redact
    stub_request(:post, "#{HOST}/api/v1/subscribers/redact.json")
      .to_return(status: 200, body: { message: 'Subscriber successfully redacted' }.to_json)

    result = @subs.redact('jane@example.com')
    assert_includes result['message'], 'redacted'
  end

  # --- Double opt-in ---

  def test_create_with_double_opt_in_boolean_at_top_level
    stub_request(:post, "#{HOST}/api/v1/subscribers.json")
      .with(body: hash_including(
        'subscriber' => hash_including('email' => 'a@b.com'),
        'double_opt_in' => true
      ))
      .to_return(status: 201, body: { id: 1, confirmation_status: 'pending' }.to_json)

    @subs.create(email: 'a@b.com', double_opt_in: true)
  end

  def test_create_with_double_opt_in_hash_at_top_level
    stub_request(:post, "#{HOST}/api/v1/subscribers.json")
      .with(body: hash_including(
        'subscriber' => hash_including('email' => 'a@b.com'),
        'double_opt_in' => hash_including('reply_to' => 'r@b.com')
      ))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @subs.create(email: 'a@b.com', double_opt_in: { reply_to: 'r@b.com' })
  end

  def test_create_double_opt_in_not_nested_under_subscriber
    stub_request(:post, "#{HOST}/api/v1/subscribers.json")
      .to_return(status: 201, body: { id: 1 }.to_json)

    @subs.create(email: 'a@b.com', double_opt_in: true, confirmation_template_id: 9)

    assert_requested(:post, "#{HOST}/api/v1/subscribers.json") do |req|
      payload = JSON.parse(req.body)
      payload['double_opt_in'] == true &&
        payload['confirmation_template_id'] == 9 &&
        !payload['subscriber'].key?('double_opt_in') &&
        !payload['subscriber'].key?('confirmation_template_id')
    end
  end

  def test_create_without_double_opt_in_omits_keys
    stub_request(:post, "#{HOST}/api/v1/subscribers.json")
      .to_return(status: 201, body: { id: 1 }.to_json)

    @subs.create(email: 'a@b.com')

    assert_requested(:post, "#{HOST}/api/v1/subscribers.json") do |req|
      payload = JSON.parse(req.body)
      !payload.key?('double_opt_in') && !payload.key?('confirmation_template_id')
    end
  end
end
