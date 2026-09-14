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
end
