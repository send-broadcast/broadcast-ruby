# frozen_string_literal: true

require 'test_helper'

class TestGlobalSuppressions < Minitest::Test
  def setup
    @global = new_client.global_suppressions
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/global_suppressions.json?page=1")
      .to_return(status: 200, body: {
        suppressions: [{ email: 'blocked@example.com', scope: 'global', broadcast_channel_id: nil }],
        pagination: { total: 1 }
      }.to_json)

    result = @global.list(page: 1)
    assert_equal 'global', result['suppressions'].first['scope']
  end

  def test_add
    stub_request(:post, "#{HOST}/api/v1/global_suppressions.json")
      .with(body: hash_including('email' => 'blocked@example.com'))
      .to_return(status: 201, body: { id: 1, email: 'blocked@example.com', scope: 'global' }.to_json)

    result = @global.add('blocked@example.com')
    assert_equal 'global', result['scope']
  end

  # The API answers 401 (not 403) for a token without suppression permissions,
  # matching every other endpoint — so this surfaces as AuthenticationError.
  def test_add_requires_admin_token
    stub_request(:post, "#{HOST}/api/v1/global_suppressions.json")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

    assert_raises(Broadcast::AuthenticationError) { @global.add('blocked@example.com') }
  end

  def test_remove
    stub_request(:delete, "#{HOST}/api/v1/global_suppressions.json")
      .with(body: hash_including('email' => 'blocked@example.com'))
      .to_return(status: 200, body: { email: 'blocked@example.com', removed: true }.to_json)

    result = @global.remove('blocked@example.com')
    assert result['removed']
  end

  def test_bulk_add
    stub_request(:post, "#{HOST}/api/v1/global_suppressions/bulk.json")
      .with(body: hash_including('emails' => ['a@example.com', 'b@example.com']))
      .to_return(status: 200, body: { added: 1, already_suppressed: 1, invalid: [] }.to_json)

    result = @global.bulk_add(['a@example.com', 'b@example.com'])
    assert_equal 1, result['already_suppressed']
  end

  def test_bulk_remove
    stub_request(:delete, "#{HOST}/api/v1/global_suppressions/bulk.json")
      .with(body: hash_including('emails' => ['a@example.com']))
      .to_return(status: 200, body: { removed: 0, not_found: 1 }.to_json)

    result = @global.bulk_remove(['a@example.com'])
    assert_equal 1, result['not_found']
  end

  def test_no_check_method
    refute_respond_to @global, :check
  end
end
