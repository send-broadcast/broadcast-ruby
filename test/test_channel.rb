# frozen_string_literal: true

require 'test_helper'

class TestChannel < Minitest::Test
  def setup
    @client = new_client
  end

  # The body mirrors what Api::V1::ChannelDesignController#show renders: the
  # brand kit fully resolved, with the logo as a public URL.
  def test_design_returns_the_resolved_brand_kit
    stub_request(:get, "#{HOST}/api/v1/channel/design")
      .to_return(status: 200, body: {
        colors: { accent: '#ff5500', text: '#18181b' },
        typography: { font: 'georgia', font_stack: 'Georgia, serif' },
        layout: { width: 600, radius: 8 },
        brand: {
          logo_url: 'https://broadcast.test/files/abc123',
          logo_width: 180,
          website_url: 'https://acme.example',
          social_links: [{ network: 'x', url: 'https://x.com/acme' }],
          social_icon_style: 'dark'
        }
      }.to_json)

    design = @client.channel.design

    assert_equal '#ff5500', design['colors']['accent']
    assert_equal 'Georgia, serif', design['typography']['font_stack']
    assert_equal 600, design['layout']['width']
    assert_equal 'https://broadcast.test/files/abc123', design['brand']['logo_url']
    assert_equal [{ 'network' => 'x', 'url' => 'https://x.com/acme' }], design['brand']['social_links']
  end

  def test_design_sends_no_parameters
    stub = stub_request(:get, "#{HOST}/api/v1/channel/design")
           .to_return(status: 200, body: {}.to_json)

    @client.channel.design

    assert_requested(stub)
  end

  def test_design_without_templates_read_permission_raises
    stub_request(:get, "#{HOST}/api/v1/channel/design")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

    assert_raises(Broadcast::AuthenticationError) { @client.channel.design }
  end

  def test_channel_sub_client_is_memoized
    assert_same @client.channel, @client.channel
    assert_instance_of Broadcast::Resources::Channel, @client.channel
  end

  # An admin token reads the kit of the channel it is scoped to.
  def test_channel_scope_is_applied
    stub_request(:get, %r{#{HOST}/api/v1/channel/design.*broadcast_channel_id=42})
      .to_return(status: 200, body: {}.to_json)

    new_client(broadcast_channel_id: 42).channel.design

    assert_requested(:get, /broadcast_channel_id=42/)
  end

  # --- Channel settings (Broadcast 2.46.0) ---

  def test_settings_reads_the_channel_settings
    stub_request(:get, "#{HOST}/api/v1/channel/settings")
      .to_return(status: 200, body: {
        general: { name: 'Northwind', language: 'de' },
        unsubscribe_page: { legal_notice_url: 'https://northwind.example/impressum' }
      }.to_json)

    settings = @client.channel.settings

    assert_equal 'de', settings['general']['language']
    assert_equal 'https://northwind.example/impressum', settings['unsubscribe_page']['legal_notice_url']
  end

  def test_update_settings_wraps_the_groups_under_channel_settings
    legal = { legal_notice_url: 'https://northwind.example/impressum' }
    stub = stub_request(:patch, "#{HOST}/api/v1/channel/settings")
           .with(body: { channel_settings: { unsubscribe_page: legal } }.to_json)
           .to_return(status: 200, body: { general: { name: 'Northwind' } }.to_json)

    result = @client.channel.update_settings(unsubscribe_page: legal)

    assert_requested(stub)
    assert_equal 'Northwind', result['general']['name']
  end

  def test_update_settings_exposes_warnings
    stub_request(:patch, "#{HOST}/api/v1/channel/settings")
      .to_return(status: 200, body: { general: {}, warnings: [
        { code: 'unrecognized_parameter', param: 'channel_settings.general.domain', message: 'ignored' }
      ] }.to_json)

    result = @client.channel.update_settings(general: { domain: 'x.example' })

    assert_equal 'channel_settings.general.domain', result.warnings.first.param
  end

  def test_update_settings_422_raises_validation_error
    stub_request(:patch, "#{HOST}/api/v1/channel/settings")
      .to_return(status: 422, body: { error: 'Unprocessable Content',
                                      message: 'channel_settings.general.language must be one of en, de' }.to_json)

    assert_raises(Broadcast::ValidationError) { @client.channel.update_settings(general: { language: 'xx' }) }
  end

  # --- Brand kit update (Broadcast 2.46.0) ---

  def test_update_design_wraps_the_kit_under_channel_design
    stub = stub_request(:patch, "#{HOST}/api/v1/channel/design")
           .with(body: { channel_design: { colors: { accent: '#ff5500' }, brand: { logo_url: nil } } }.to_json)
           .to_return(status: 200, body: { colors: { accent: '#ff5500' } }.to_json)

    result = @client.channel.update_design(colors: { accent: '#ff5500' }, brand: { logo_url: nil })

    assert_requested(stub)
    assert_equal '#ff5500', result['colors']['accent']
  end

  def test_update_design_exposes_warnings
    stub_request(:patch, "#{HOST}/api/v1/channel/design")
      .to_return(status: 200, body: { colors: {}, warnings: [
        { code: 'unrecognized_parameter', param: 'channel_design.layout.width', message: 'read-only' }
      ] }.to_json)

    result = @client.channel.update_design(layout: { width: 700 })

    assert_equal 'channel_design.layout.width', result.warnings.first.param
  end

  def test_update_design_applies_the_channel_scope_in_the_body
    stub = stub_request(:patch, "#{HOST}/api/v1/channel/design")
           .with(body: hash_including('broadcast_channel_id' => 42))
           .to_return(status: 200, body: {}.to_json)

    new_client(broadcast_channel_id: 42).channel.update_design(colors: { accent: '#ff5500' })

    assert_requested(stub)
  end
end
