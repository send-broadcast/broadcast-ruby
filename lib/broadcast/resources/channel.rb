# frozen_string_literal: true

module Broadcast
  module Resources
    # The token's own channel. Reads only the channel the token resolves to
    # (or, for an admin token, the channel it is scoped to); there is no
    # channel id argument.
    class Channel < Base
      # The channel's brand kit from Settings -> Brand Kit, fully resolved
      # (defaults filled in). Requires the `templates_read` permission (or,
      # from Broadcast 2.46.0, `channel_settings_read`).
      #
      # Returns a Hash with `colors`, `typography` (`font` key and email-safe
      # `font_stack`), `layout` (`width`, `radius`), and `brand` (`logo_url` as
      # a public URL or nil, `logo_width`, `website_url`, `social_links`,
      # `social_icon_style`).
      def design
        get('/api/v1/channel/design')
      end

      # Changes the brand kit (Broadcast 2.46.0 or later). Requires the
      # `channel_settings_write` permission.
      #
      # Partial: send only what changes, in the shape #design returns. An empty
      # string or nil puts a value back to its default; `social_links`
      # replaces the list. Set the logo with the `logo_url` of an image in the
      # channel's file library. Returns the whole kit after the change, with
      # any `warnings`.
      #
      #   client.channel.update_design(colors: { accent: '#ff5500' }, brand: { logo_url: nil })
      def update_design(**design)
        patch('/api/v1/channel/design', { channel_design: design })
      end

      # The channel's settings (Broadcast 2.46.0 or later), grouped like the
      # Settings pages: `general`, `sender`, `unsubscribe_page` (with the legal
      # links) and `confirmation_page`. Requires `channel_settings_read`.
      def settings
        get('/api/v1/channel/settings')
      end

      # Changes channel settings (Broadcast 2.46.0 or later). Requires
      # `channel_settings_write`.
      #
      # Partial: send only the groups and keys that change. Nested text and
      # colours merge, an empty string or nil removes a value, and
      # `languages` replaces the list. Returns every setting after the
      # change, with any `warnings`.
      #
      #   client.channel.update_settings(unsubscribe_page: { legal_notice_url: 'https://example.com/impressum' })
      def update_settings(**settings)
        patch('/api/v1/channel/settings', { channel_settings: settings })
      end
    end
  end
end
