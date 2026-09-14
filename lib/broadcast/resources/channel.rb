# frozen_string_literal: true

module Broadcast
  module Resources
    # The token's own channel. Reads only the channel the token resolves to
    # (or, for an admin token, the channel it is scoped to); there is no
    # channel id argument.
    class Channel < Base
      # The channel's brand kit from Settings -> Design, fully resolved
      # (defaults filled in), read-only. Requires the `templates_read`
      # permission.
      #
      # Returns a Hash with `colors`, `typography` (`font` key and email-safe
      # `font_stack`), `layout` (`width`, `radius`), and `brand` (`logo_url` as
      # a public URL or nil, `logo_width`, `website_url`, `social_links`,
      # `social_icon_style`).
      def design
        get('/api/v1/channel/design')
      end
    end
  end
end
