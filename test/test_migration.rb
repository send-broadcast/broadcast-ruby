# frozen_string_literal: true

require 'test_helper'

class TestMigration < Minitest::Test
  def setup
    @migration = new_client.migration
  end

  def test_manifest
    stub_request(:get, "#{HOST}/api/migration/v1/manifest?broadcast_channel_id=1")
      .to_return(status: 200, body: {
        export_format_version: 1,
        broadcast_channel: { id: 1, name: 'Main' },
        counts: { subscribers: 500, templates: 12 }
      }.to_json)

    result = @migration.manifest(broadcast_channel_id: 1)
    assert_equal 1, result['export_format_version']
    assert_equal 500, result['counts']['subscribers']
  end

  def test_manifest_accepts_days_history
    stub_request(:get, "#{HOST}/api/migration/v1/manifest?broadcast_channel_id=1&days_history=365")
      .to_return(status: 200, body: {}.to_json)

    @migration.manifest(broadcast_channel_id: 1, days_history: 365)
    assert_requested(:get, /days_history=365/)
  end

  def test_every_collection_endpoint_is_defined
    Broadcast::Resources::Migration::COLLECTIONS.each do |collection|
      assert_respond_to @migration, collection
    end
  end

  def test_collection_list
    stub_request(:get, "#{HOST}/api/migration/v1/subscribers?broadcast_channel_id=1&limit=50")
      .to_return(status: 200, body: {
        data: [{ id: 1, email: 'a@b.com' }],
        pagination: { total: 1, limit: 50, offset: 0, has_more: false }
      }.to_json)

    result = @migration.subscribers(broadcast_channel_id: 1, limit: 50)
    assert_equal 'a@b.com', result['data'].first['email']
    assert_equal false, result['pagination']['has_more']
  end

  # Binary assets must not come back tagged as UTF-8 — writing them straight to
  # disk has to round-trip byte for byte.
  def test_file_asset_download_returns_raw_bytes
    png = "\x89PNG\r\n\x1A\n".dup.force_encoding(Encoding::BINARY)
    stub_request(:get, "#{HOST}/api/migration/v1/file_assets/7/download?broadcast_channel_id=1")
      .to_return(status: 200, body: png, headers: { 'Content-Type' => 'image/png' })

    result = @migration.download_file_asset(7, broadcast_channel_id: 1)
    assert_kind_of String, result
    assert_equal Encoding::BINARY, result.encoding
    assert_equal png, result
  end

  def test_text_raw_response_keeps_declared_charset
    stub_request(:get, "#{HOST}/api/v1/skill")
      .to_return(status: 200, body: 'héllo',
                 headers: { 'Content-Type' => 'text/plain; charset=utf-8' })

    assert_equal 'héllo', new_client.skill
  end

  # --- each_record ---

  def test_each_record_pages_until_exhausted
    stub_request(:get, "#{HOST}/api/migration/v1/subscribers?broadcast_channel_id=1&limit=2&offset=0")
      .to_return(status: 200, body: {
        data: [{ id: 1 }, { id: 2 }],
        pagination: { total: 3, limit: 2, offset: 0, has_more: true }
      }.to_json)
    stub_request(:get, "#{HOST}/api/migration/v1/subscribers?broadcast_channel_id=1&limit=2&offset=2")
      .to_return(status: 200, body: {
        data: [{ id: 3 }],
        pagination: { total: 3, limit: 2, offset: 2, has_more: false }
      }.to_json)

    ids = []
    @migration.each_record(:subscribers, limit: 2, broadcast_channel_id: 1) { |record| ids << record['id'] }

    assert_equal [1, 2, 3], ids
  end

  # The server clamps limit to 250; advancing by the requested page size rather
  # than the granted one would skip records.
  def test_each_record_advances_by_server_granted_limit
    stub_request(:get, "#{HOST}/api/migration/v1/subscribers?broadcast_channel_id=1&limit=1000&offset=0")
      .to_return(status: 200, body: {
        data: [{ id: 1 }],
        pagination: { total: 2, limit: 250, offset: 0, has_more: true }
      }.to_json)
    stub_request(:get, "#{HOST}/api/migration/v1/subscribers?broadcast_channel_id=1&limit=1000&offset=250")
      .to_return(status: 200, body: {
        data: [{ id: 2 }],
        pagination: { total: 2, limit: 250, offset: 250, has_more: false }
      }.to_json)

    ids = @migration.each_record(:subscribers, limit: 1000, broadcast_channel_id: 1).map { |r| r['id'] }
    assert_equal [1, 2], ids
  end

  def test_each_record_returns_enumerator_without_block
    stub_request(:get, "#{HOST}/api/migration/v1/tags?broadcast_channel_id=1&limit=250&offset=0")
      .to_return(status: 200, body: {
        data: [{ name: 'vip' }],
        pagination: { total: 1, limit: 250, offset: 0, has_more: false }
      }.to_json)

    enum = @migration.each_record(:tags, broadcast_channel_id: 1)
    assert_kind_of Enumerator, enum
    assert_equal(['vip'], enum.map { |tag| tag['name'] })
  end

  def test_each_record_handles_empty_collection
    stub_request(:get, "#{HOST}/api/migration/v1/users?broadcast_channel_id=1&limit=250&offset=0")
      .to_return(status: 200, body: {
        data: [], pagination: { total: 0, limit: 250, offset: 0, has_more: false }
      }.to_json)

    assert_empty @migration.each_record(:users, broadcast_channel_id: 1).to_a
  end

  # --- Channel scoping ---

  def test_channel_id_auto_injected_from_config
    stub_request(:get, "#{HOST}/api/migration/v1/segments?broadcast_channel_id=42")
      .to_return(status: 200, body: { data: [] }.to_json)

    new_client(broadcast_channel_id: 42).migration.segments
    assert_requested(:get, /broadcast_channel_id=42/)
  end

  def test_migration_sub_client_is_memoized
    client = new_client
    assert_same client.migration, client.migration
  end
end
