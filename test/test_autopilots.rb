# frozen_string_literal: true

require 'test_helper'

class TestAutopilots < Minitest::Test
  def setup
    @autopilots = new_client.autopilots
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/autopilots")
      .to_return(status: 200, body: { data: [{ id: 1, name: 'Weekly Digest' }], total: 1 }.to_json)

    result = @autopilots.list
    assert_equal 'Weekly Digest', result['data'].first['name']
  end

  def test_list_with_paging
    stub_request(:get, "#{HOST}/api/v1/autopilots?limit=10&offset=20")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    @autopilots.list(limit: 10, offset: 20)
    assert_requested(:get, "#{HOST}/api/v1/autopilots?limit=10&offset=20")
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/autopilots/1")
      .to_return(status: 200, body: { id: 1, name: 'Weekly Digest', status: 'inactive' }.to_json)

    result = @autopilots.get_autopilot(1)
    assert_equal 'inactive', result['status']
  end

  def test_create_wraps_under_autopilot_key
    stub_request(:post, "#{HOST}/api/v1/autopilots")
      .with(body: hash_including('autopilot' => hash_including('name' => 'Weekly Digest')))
      .to_return(status: 201, body: { id: 3 }.to_json)

    result = @autopilots.create(name: 'Weekly Digest', schedule_frequency: 'weekly')
    assert_equal 3, result['id']
  end

  def test_update_wraps_under_autopilot_key
    stub_request(:patch, "#{HOST}/api/v1/autopilots/1")
      .with(body: hash_including('autopilot' => hash_including('name' => 'Renamed')))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @autopilots.update(1, name: 'Renamed')
  end

  # The API redacts the stored key; writing a masked value back would destroy
  # the real credential. Same guard as EmailServers.
  def test_update_strips_a_redacted_api_key
    stub_request(:patch, "#{HOST}/api/v1/autopilots/1")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @autopilots.update(1, name: 'Renamed', openrouter_api_key: '••••••••')

    assert_requested(:patch, "#{HOST}/api/v1/autopilots/1") do |req|
      !JSON.parse(req.body)['autopilot'].key?('openrouter_api_key')
    end
  end

  def test_update_keeps_a_real_api_key
    stub_request(:patch, "#{HOST}/api/v1/autopilots/1")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @autopilots.update(1, openrouter_api_key: 'sk-or-real-key')

    assert_requested(:patch, "#{HOST}/api/v1/autopilots/1") do |req|
      JSON.parse(req.body)['autopilot']['openrouter_api_key'] == 'sk-or-real-key'
    end
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/autopilots/1")
      .to_return(status: 200, body: {}.to_json)

    @autopilots.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/autopilots/1")
  end

  # --- Lifecycle ---

  def test_activate
    stub_request(:post, "#{HOST}/api/v1/autopilots/1/activate")
      .to_return(status: 200, body: { id: 1, status: 'active' }.to_json)

    assert_equal 'active', @autopilots.activate(1)['status']
  end

  def test_pause
    stub_request(:post, "#{HOST}/api/v1/autopilots/1/pause")
      .to_return(status: 200, body: { id: 1, status: 'paused' }.to_json)

    assert_equal 'paused', @autopilots.pause(1)['status']
  end

  def test_deactivate
    stub_request(:post, "#{HOST}/api/v1/autopilots/1/deactivate")
      .to_return(status: 200, body: { id: 1, status: 'inactive' }.to_json)

    assert_equal 'inactive', @autopilots.deactivate(1)['status']
  end

  def test_activate_surfaces_missing_prerequisites
    stub_request(:post, "#{HOST}/api/v1/autopilots/1/activate")
      .to_return(status: 422, body: { error: 'At least one active source is required' }.to_json)

    error = assert_raises(Broadcast::ValidationError) { @autopilots.activate(1) }
    assert_match(/active source/, error.message)
  end

  def test_trigger_run
    stub_request(:post, "#{HOST}/api/v1/autopilots/1/trigger_run")
      .to_return(status: 202, body: { id: 9, status: 'pending' }.to_json)

    result = @autopilots.trigger_run(1)
    assert_equal 9, result['id']
    assert_equal 202, result.status
  end

  # --- Runs ---

  def test_runs
    stub_request(:get, "#{HOST}/api/v1/autopilots/1/runs")
      .to_return(status: 200, body: { data: [{ id: 9, status: 'completed' }], total: 1 }.to_json)

    result = @autopilots.runs(1)
    assert_equal 'completed', result['data'].first['status']
  end

  def test_runs_with_paging
    stub_request(:get, "#{HOST}/api/v1/autopilots/1/runs?limit=5")
      .to_return(status: 200, body: { data: [], total: 0 }.to_json)

    @autopilots.runs(1, limit: 5)
    assert_requested(:get, "#{HOST}/api/v1/autopilots/1/runs?limit=5")
  end

  # --- Client wiring ---

  def test_sub_client_is_memoized
    client = new_client
    assert_same client.autopilots, client.autopilots
    assert_instance_of Broadcast::Resources::Autopilots, client.autopilots
  end
end
