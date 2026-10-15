# frozen_string_literal: true

require 'test_helper'
require 'tempfile'
require 'base64'
require 'logger'

class TestFileAssets < Minitest::Test
  PNG = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR".b

  def setup
    @files = new_client.file_assets
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/file_assets?filter=logo&limit=10")
      .to_return(status: 200, body: { data: [{ id: 1, filename: 'logo.png' }], total: 1 }.to_json)

    result = @files.list(filter: 'logo', limit: 10)
    assert_equal 'logo.png', result['data'].first['filename']
    assert_equal 1, result['total']
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/file_assets/7")
      .to_return(status: 200, body: { id: 7, url: 'https://broadcast.test/files/abc-logo.png' }.to_json)

    assert_equal 'https://broadcast.test/files/abc-logo.png', @files.get_file_asset(7)['url']
  end

  def test_upload_from_a_path_sends_multipart
    file = Tempfile.new(['logo', '.png'])
    file.binmode
    file.write(PNG)
    file.close

    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .with do |req|
        req.headers['Content-Type'].start_with?('multipart/form-data; boundary=') &&
          req.body.b.include?("name=\"file\"; filename=\"#{File.basename(file.path)}\"") &&
          req.body.b.include?('Content-Type: image/png') &&
          req.body.b.include?(PNG)
      end
      .to_return(status: 201, body: { id: 9, filename: File.basename(file.path) }.to_json)

    assert_equal 9, @files.upload(file.path)['id']
  ensure
    file&.unlink
  end

  def test_upload_from_an_io_with_a_filename_and_restriction
    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .with do |req|
        body = req.body.b
        body.include?('filename="banner.gif"') && body.include?('Content-Type: image/gif') &&
          body.include?("name=\"channel_restricted\"\r\n\r\ntrue")
      end
      .to_return(status: 201, body: { id: 10 }.to_json)

    result = @files.upload(StringIO.new('GIF89a'), filename: 'banner.gif', channel_restricted: true)
    assert_equal 10, result['id']
  end

  def test_upload_of_an_io_needs_a_filename
    assert_raises(ArgumentError) { @files.upload(StringIO.new(PNG)) }
  end

  def test_upload_sends_the_idempotency_key
    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .with(headers: { 'Idempotency-Key' => 'logo-1' })
      .to_return(status: 201, body: { id: 11 }.to_json, headers: { 'Idempotency-Replayed' => 'true' })

    result = @files.upload(StringIO.new(PNG), filename: 'logo.png', idempotency_key: 'logo-1')
    assert_predicate result, :idempotent_replay?
  end

  def test_upload_with_a_channel_scope_sends_it_as_a_form_field
    client = new_client(broadcast_channel_id: 42)
    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .with { |req| req.body.b.include?("name=\"broadcast_channel_id\"\r\n\r\n42") }
      .to_return(status: 201, body: { id: 12 }.to_json)

    client.file_assets.upload(StringIO.new(PNG), filename: 'logo.png')
  end

  def test_upload_base64_sends_json
    data = Base64.strict_encode64(PNG)
    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .with(headers: { 'Content-Type' => 'application/json' },
            body: { filename: 'logo.png', data: data, content_type: 'image/png' }.to_json)
      .to_return(status: 201, body: { id: 13 }.to_json)

    assert_equal 13, @files.upload_base64(filename: 'logo.png', data: data, content_type: 'image/png')['id']
  end

  def test_upload_errors_surface_as_validation_errors
    stub_request(:post, "#{HOST}/api/v1/file_assets")
      .to_return(status: 422, body: { error: 'Unprocessable Content', message: 'data is not valid base64' }.to_json)

    assert_raises(Broadcast::ValidationError) { @files.upload_base64(filename: 'x.png', data: '!!') }
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/file_assets/7")
      .to_return(status: 200, body: { message: 'File asset deleted successfully' }.to_json)

    @files.delete(7)
    assert_requested(:delete, "#{HOST}/api/v1/file_assets/7")
  end

  def test_delete_of_a_brand_kit_logo_raises_a_validation_error
    stub_request(:delete, "#{HOST}/api/v1/file_assets/7")
      .to_return(status: 422, body: { error: "This file is the channel's Brand Kit logo." }.to_json)

    error = assert_raises(Broadcast::ValidationError) { @files.delete(7) }
    assert_includes error.message, 'Brand Kit logo'
  end

  def test_debug_log_cuts_base64_data_short
    log = StringIO.new
    client = new_client(debug: true, logger: Logger.new(log))
    stub_request(:post, "#{HOST}/api/v1/file_assets").to_return(status: 201, body: { id: 1 }.to_json)
    data = Base64.strict_encode64(PNG * 200)

    client.file_assets.upload_base64(filename: 'logo.png', data: data)

    refute_includes log.string, data
    assert_includes log.string, "(#{data.length} characters)"
  end

  def test_debug_log_does_not_dump_file_bytes
    log = StringIO.new
    client = new_client(debug: true, logger: Logger.new(log))
    stub_request(:post, "#{HOST}/api/v1/file_assets").to_return(status: 201, body: { id: 1 }.to_json)

    client.file_assets.upload(StringIO.new(PNG * 100), filename: 'logo.png')

    refute_includes log.string, 'IHDR'
    assert_includes log.string, 'logo.png'
  end
end
