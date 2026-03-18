# frozen_string_literal: true

require 'test_helper'

class TestSequences < Minitest::Test
  def setup
    @seq = new_client.sequences
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/sequences")
      .to_return(status: 200, body: { data: [{ id: 1, label: 'Onboarding' }] }.to_json)

    result = @seq.list
    assert_equal 'Onboarding', result['data'].first['label']
  end

  def test_get_sequence
    stub_request(:get, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: { id: 1 }.to_json)

    result = @seq.get_sequence(1)
    assert_equal 1, result['id']
  end

  def test_get_sequence_with_steps
    stub_request(:get, "#{HOST}/api/v1/sequences/1?include_steps=true")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @seq.get_sequence(1, include_steps: true)
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/sequences")
      .with(body: hash_including('label' => 'New'))
      .to_return(status: 201, body: { id: 5 }.to_json)

    result = @seq.create(label: 'New', active: false)
    assert_equal 5, result['id']
  end

  def test_create_with_tag_trigger
    stub_request(:post, "#{HOST}/api/v1/sequences")
      .with(body: hash_including('init_tag' => 'trial'))
      .to_return(status: 201, body: { id: 6 }.to_json)

    @seq.create(label: 'Trial', init_tag: 'trial', active: true)
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @seq.update(1, label: 'Updated')
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/sequences/1")
      .to_return(status: 200, body: {}.to_json)

    @seq.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/sequences/1")
  end

  # --- Enrollment ---

  def test_add_subscriber
    stub_request(:post, "#{HOST}/api/v1/sequences/1/add_subscriber")
      .with(body: hash_including('email' => 'jane@example.com'))
      .to_return(status: 201, body: {}.to_json)

    @seq.add_subscriber(1, email: 'jane@example.com')
  end

  def test_remove_subscriber
    stub_request(:delete, "#{HOST}/api/v1/sequences/1/remove_subscriber")
      .to_return(status: 200, body: {}.to_json)

    @seq.remove_subscriber(1, email: 'jane@example.com')
    assert_requested(:delete, "#{HOST}/api/v1/sequences/1/remove_subscriber")
  end

  def test_list_subscribers
    stub_request(:get, "#{HOST}/api/v1/sequences/1/list_subscribers?page=1")
      .to_return(status: 200, body: { subscribers: [] }.to_json)

    @seq.list_subscribers(1, page: 1)
  end

  # --- Steps ---

  def test_list_steps
    stub_request(:get, "#{HOST}/api/v1/sequences/1/steps")
      .to_return(status: 200, body: { data: [] }.to_json)

    @seq.list_steps(1)
  end

  def test_get_step
    stub_request(:get, "#{HOST}/api/v1/sequences/1/steps/10")
      .to_return(status: 200, body: { id: 10, action: 'send_email' }.to_json)

    result = @seq.get_step(1, 10)
    assert_equal 'send_email', result['action']
  end

  def test_create_email_step
    stub_request(:post, "#{HOST}/api/v1/sequences/1/steps")
      .with(body: hash_including('action' => 'send_email', 'subject' => 'Welcome!'))
      .to_return(status: 201, body: { id: 10 }.to_json)

    @seq.create_step(1, action: 'send_email', label: 'Welcome', parent_id: 1, subject: 'Welcome!', body: '<p>Hi</p>')
  end

  def test_create_delay_step
    stub_request(:post, "#{HOST}/api/v1/sequences/1/steps")
      .with(body: hash_including('action' => 'delay', 'delay' => 86_400))
      .to_return(status: 201, body: { id: 11 }.to_json)

    @seq.create_step(1, action: 'delay', label: 'Wait 1 day', parent_id: 10, delay: 86_400)
  end

  def test_create_condition_step
    stub_request(:post, "#{HOST}/api/v1/sequences/1/steps")
      .with(body: hash_including('action' => 'condition', 'condition_setting' => 'previous_email_opened'))
      .to_return(status: 201, body: { id: 12 }.to_json)

    @seq.create_step(1, action: 'condition', label: 'Opened?', parent_id: 11,
                        condition_setting: 'previous_email_opened')
  end

  def test_update_step
    stub_request(:patch, "#{HOST}/api/v1/sequences/1/steps/10")
      .to_return(status: 200, body: { id: 10 }.to_json)

    @seq.update_step(1, 10, label: 'Updated')
  end

  def test_move_step
    stub_request(:post, "#{HOST}/api/v1/sequences/1/steps/10/move")
      .with(body: hash_including('under_id' => 5))
      .to_return(status: 200, body: {}.to_json)

    @seq.move_step(1, 10, under_id: 5)
  end

  def test_delete_step
    stub_request(:delete, "#{HOST}/api/v1/sequences/1/steps/10")
      .to_return(status: 200, body: {}.to_json)

    @seq.delete_step(1, 10)
    assert_requested(:delete, "#{HOST}/api/v1/sequences/1/steps/10")
  end
end
