# frozen_string_literal: true

require 'test_helper'

class TestTransactionals < Minitest::Test
  def setup
    @tx = new_client.transactionals
  end

  def test_create_basic
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('to' => 'a@b.com', 'subject' => 'Hi', 'body' => '<p>hi</p>'))
      .to_return(status: 201, body: { id: 1 }.to_json)

    result = @tx.create(to: 'a@b.com', subject: 'Hi', body: '<p>hi</p>')
    assert_equal 1, result['id']
  end

  def test_create_with_template_id
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('to' => 'a@b.com', 'template_id' => 99))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @tx.create(to: 'a@b.com', template_id: 99)
  end

  def test_create_with_preheader_and_include_unsubscribe_link
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('preheader' => 'pre', 'include_unsubscribe_link' => true))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @tx.create(to: 'a@b.com', subject: 'S', body: 'B', preheader: 'pre', include_unsubscribe_link: true)
  end

  def test_create_with_double_opt_in_boolean
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('double_opt_in' => true))
      .to_return(status: 201, body: { id: 1, confirmation_status: 'pending' }.to_json)

    result = @tx.create(to: 'a@b.com', subject: 'S', body: 'B', double_opt_in: true)
    assert_equal 'pending', result['confirmation_status']
  end

  def test_create_with_double_opt_in_hash
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including(
        'double_opt_in' => hash_including(
          'reply_to' => 'r@b.com',
          'confirmation_template_id' => 5
        )
      ))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @tx.create(
      to: 'a@b.com',
      subject: 'S',
      body: 'B',
      double_opt_in: { reply_to: 'r@b.com', confirmation_template_id: 5 }
    )
  end

  def test_create_with_subscriber_attrs
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including(
        'subscriber' => hash_including('first_name' => 'Jane', 'last_name' => 'Doe')
      ))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @tx.create(to: 'a@b.com', subject: 'S', body: 'B',
               subscriber: { first_name: 'Jane', last_name: 'Doe' })
  end

  def test_create_omits_nil_optionals
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .to_return(status: 201, body: { id: 1 }.to_json)

    @tx.create(to: 'a@b.com', subject: 'S', body: 'B')

    assert_requested(:post, "#{HOST}/api/v1/transactionals.json") do |req|
      payload = JSON.parse(req.body)
      !payload.key?('reply_to') &&
        !payload.key?('preheader') &&
        !payload.key?('template_id') &&
        !payload.key?('double_opt_in') &&
        !payload.key?('confirmation_template_id') &&
        !payload.key?('subscriber')
    end
  end

  def test_get_transactional
    stub_request(:get, "#{HOST}/api/v1/transactionals/42.json")
      .to_return(status: 200, body: { id: 42, status: 'sent' }.to_json)

    result = @tx.get_transactional(42)
    assert_equal 'sent', result['status']
  end

  # send_email shim still works
  def test_send_email_shim_delegates
    stub_request(:post, "#{HOST}/api/v1/transactionals.json")
      .with(body: hash_including('to' => 'a@b.com', 'subject' => 'Hi', 'body' => 'b'))
      .to_return(status: 201, body: { id: 7 }.to_json)

    result = new_client.send_email(to: 'a@b.com', subject: 'Hi', body: 'b')
    assert_equal 7, result['id']
  end
end
