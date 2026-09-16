# frozen_string_literal: true

require 'test_helper'

class TestUsers < Minitest::Test
  def setup
    @users = new_client.users
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/users")
      .to_return(status: 200, body: { data: [{ id: 1 }], total: 1 }.to_json)

    result = @users.list
    assert_equal 1, result['total']
  end

  def test_list_with_query_params
    stub_request(:get, %r{#{HOST}/api/v1/users})
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    @users.list(limit: 10, offset: 20, q: 'ada', status: 'active')

    assert_requested(:get, /limit=10/)
    assert_requested(:get, /offset=20/)
    assert_requested(:get, /q=ada/)
    assert_requested(:get, /status=active/)
  end

  def test_list_omits_nil_params
    stub_request(:get, "#{HOST}/api/v1/users")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    @users.list

    assert_requested(:get, "#{HOST}/api/v1/users")
  end

  def test_get_user
    stub_request(:get, "#{HOST}/api/v1/users/3")
      .to_return(status: 200, body: { id: 3, email: 'ada@example.com' }.to_json)

    result = @users.get_user(3)
    assert_equal 'ada@example.com', result['email']
  end

  def test_create_wraps_under_user
    stub_request(:post, "#{HOST}/api/v1/users")
      .with(body: hash_including('user' => hash_including('email' => 'ada@example.com')))
      .to_return(status: 201, body: { id: 4 }.to_json)

    @users.create(email: 'ada@example.com', first_name: 'Ada', last_name: 'Lovelace', password: 'x' * 12)
  end

  def test_update_wraps_under_user
    stub_request(:patch, "#{HOST}/api/v1/users/3")
      .with(body: hash_including('user' => hash_including('first_name' => 'Grace')))
      .to_return(status: 200, body: { id: 3 }.to_json)

    @users.update(3, first_name: 'Grace')
  end

  def test_deactivate
    stub_request(:post, "#{HOST}/api/v1/users/3/deactivate")
      .to_return(status: 200, body: { id: 3, active: false }.to_json)

    result = @users.deactivate(3)
    assert_equal false, result['active']
  end

  def test_activate
    stub_request(:post, "#{HOST}/api/v1/users/3/activate")
      .to_return(status: 200, body: { id: 3, active: true }.to_json)

    result = @users.activate(3)
    assert_equal true, result['active']
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/users/3")
      .to_return(status: 200, body: { message: 'User deleted successfully' }.to_json)

    result = @users.delete(3)
    assert_includes result['message'], 'deleted'
  end

  def test_channel_permissions
    stub_request(:get, "#{HOST}/api/v1/users/3/channel_permissions")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    result = @users.channel_permissions(3)
    assert_equal 0, result['total']
  end

  def test_set_channel_permissions_with_permissions
    stub_request(:put, "#{HOST}/api/v1/users/3/channel_permissions/7")
      .with(body: hash_including('permissions' => { 'subscribers_read' => true }))
      .to_return(status: 200, body: { broadcast_channel_id: 7 }.to_json)

    @users.set_channel_permissions(3, 7, permissions: { subscribers_read: true })

    assert_requested(:put, "#{HOST}/api/v1/users/3/channel_permissions/7")
  end

  def test_set_channel_permissions_with_role
    stub_request(:put, "#{HOST}/api/v1/users/3/channel_permissions/7")
      .with(body: hash_including('role' => 'Editor'))
      .to_return(status: 200, body: { broadcast_channel_id: 7 }.to_json)

    @users.set_channel_permissions(3, 7, role: 'Editor')
  end

  def test_set_channel_permissions_with_preset_id
    stub_request(:put, "#{HOST}/api/v1/users/3/channel_permissions/7")
      .with(body: hash_including('preset_id' => 12))
      .to_return(status: 200, body: { broadcast_channel_id: 7 }.to_json)

    @users.set_channel_permissions(3, 7, preset_id: 12)
  end

  def test_set_channel_permissions_requires_exactly_one_option
    assert_raises(ArgumentError) { @users.set_channel_permissions(3, 7) }

    assert_raises(ArgumentError) do
      @users.set_channel_permissions(3, 7, role: 'Editor', preset_id: 12)
    end

    assert_raises(ArgumentError) do
      @users.set_channel_permissions(3, 7, permissions: { subscribers_read: true }, role: 'Editor', preset_id: 12)
    end
  end

  def test_remove_channel_permissions
    stub_request(:delete, "#{HOST}/api/v1/users/3/channel_permissions/7")
      .to_return(status: 200, body: { message: 'Channel permissions removed successfully' }.to_json)

    result = @users.remove_channel_permissions(3, 7)
    assert_includes result['message'], 'removed'
  end

  def test_bulk_channel_permissions_with_role
    stub_request(:post, "#{HOST}/api/v1/users/3/channel_permissions/bulk")
      .with(body: hash_including('broadcast_channel_ids' => [1, 2], 'role' => 'Viewer'))
      .to_return(status: 200, body: { applied: [], failed: [] }.to_json)

    @users.bulk_channel_permissions(3, broadcast_channel_ids: [1, 2], role: 'Viewer')
  end

  def test_bulk_channel_permissions_requires_exactly_one_option
    assert_raises(ArgumentError) do
      @users.bulk_channel_permissions(3, broadcast_channel_ids: [1, 2])
    end

    assert_raises(ArgumentError) do
      @users.bulk_channel_permissions(3, broadcast_channel_ids: [1, 2], role: 'Viewer', preset_id: 5)
    end
  end

  def test_system_permissions
    stub_request(:get, "#{HOST}/api/v1/users/3/system_permissions")
      .to_return(status: 200, body: { user_management: true }.to_json)

    result = @users.system_permissions(3)
    assert_equal true, result['user_management']
  end

  def test_update_system_permissions_wraps_under_permissions
    stub_request(:patch, "#{HOST}/api/v1/users/3/system_permissions")
      .with(body: { 'permissions' => { 'user_management' => true } })
      .to_return(status: 200, body: { user_management: true }.to_json)

    @users.update_system_permissions(3, { user_management: true })
  end

  def test_non_admin_token_raises_authorization_error
    stub_request(:get, "#{HOST}/api/v1/users")
      .to_return(status: 403, body: { error: 'Admin API token required for user management' }.to_json)

    assert_raises(Broadcast::AuthorizationError) { @users.list }
  end

  def test_sudo_update_raises_authorization_error
    stub_request(:patch, "#{HOST}/api/v1/users/9")
      .to_return(status: 403, body: { error: 'Sudo users cannot be changed through the API' }.to_json)

    assert_raises(Broadcast::AuthorizationError) { @users.update(9, first_name: 'Nope') }
  end

  def test_users_sub_client_is_memoized
    client = new_client
    assert_same client.users, client.users
    assert_instance_of Broadcast::Resources::Users, client.users
  end
end
