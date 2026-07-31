# frozen_string_literal: true

require 'test_helper'

class TestSuppressions < Minitest::Test
  def setup
    @suppressions = new_client.suppressions
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/suppressions.json?page=1")
      .to_return(status: 200, body: {
        suppressions: [{ email: 'blocked@example.com', scope: 'channel' }],
        pagination: { total: 1 }
      }.to_json)

    result = @suppressions.list(page: 1)
    assert_equal 1, result['suppressions'].length
    assert_equal 'channel', result['suppressions'].first['scope']
  end

  def test_list_with_email_filter
    stub_request(:get, %r{#{HOST}/api/v1/suppressions\.json})
      .to_return(status: 200, body: { suppressions: [] }.to_json)

    @suppressions.list(email: 'example.com')
    assert_requested(:get, /email=example\.com/)
  end

  def test_add
    stub_request(:post, "#{HOST}/api/v1/suppressions.json")
      .with(body: hash_including('email' => 'blocked@example.com'))
      .to_return(status: 201, body: { id: 1, email: 'blocked@example.com', scope: 'channel' }.to_json)

    result = @suppressions.add('blocked@example.com')
    assert_equal 'blocked@example.com', result['email']
  end

  def test_add_already_suppressed_is_success
    stub_request(:post, "#{HOST}/api/v1/suppressions.json")
      .to_return(status: 200, body: { id: 1, email: 'blocked@example.com', scope: 'channel' }.to_json)

    result = @suppressions.add('blocked@example.com')
    assert_equal 'blocked@example.com', result['email']
  end

  def test_add_invalid_email
    stub_request(:post, "#{HOST}/api/v1/suppressions.json")
      .to_return(status: 422, body: { error: 'email is invalid' }.to_json)

    assert_raises(Broadcast::ValidationError) { @suppressions.add('not-an-email') }
  end

  def test_remove
    stub_request(:delete, "#{HOST}/api/v1/suppressions.json")
      .with(body: hash_including('email' => 'blocked@example.com'))
      .to_return(status: 200, body: { email: 'blocked@example.com', removed: true }.to_json)

    result = @suppressions.remove('blocked@example.com')
    assert result['removed']
  end

  def test_bulk_add
    stub_request(:post, "#{HOST}/api/v1/suppressions/bulk.json")
      .with(body: hash_including('emails' => ['a@example.com', 'b@example.com']))
      .to_return(status: 200, body: { added: 2, already_suppressed: 0, invalid: [] }.to_json)

    result = @suppressions.bulk_add(['a@example.com', 'b@example.com'])
    assert_equal 2, result['added']
  end

  def test_bulk_remove
    stub_request(:delete, "#{HOST}/api/v1/suppressions/bulk.json")
      .with(body: hash_including('emails' => ['a@example.com']))
      .to_return(status: 200, body: { removed: 1, not_found: 0 }.to_json)

    result = @suppressions.bulk_remove(['a@example.com'])
    assert_equal 1, result['removed']
  end

  def test_check
    stub_request(:get, "#{HOST}/api/v1/suppressions/check.json?email=blocked@example.com")
      .to_return(status: 200, body: { email: 'blocked@example.com', suppressed: true, scope: 'global' }.to_json)

    result = @suppressions.check('blocked@example.com')
    assert result['suppressed']
    assert_equal 'global', result['scope']
  end

  def test_check_not_suppressed
    stub_request(:get, "#{HOST}/api/v1/suppressions/check.json?email=fine@example.com")
      .to_return(status: 200, body: { email: 'fine@example.com', suppressed: false }.to_json)

    result = @suppressions.check('fine@example.com')
    refute result['suppressed']
  end
end
