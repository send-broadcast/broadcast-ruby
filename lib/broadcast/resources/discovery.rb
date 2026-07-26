# frozen_string_literal: true

module Broadcast
  module Resources
    # Introspection endpoints. Primarily built for AI agents and CLIs that need
    # to discover what a token can do before acting, but equally useful for
    # health checks and for failing fast on a misconfigured deploy.
    class Discovery < Base
      # Identity of the current token: label, type (channel_scoped or
      # admin_cross_channel), per-resource permissions, and the resolved channel.
      def whoami
        get('/api/v1/whoami')
      end

      # Channel sender config, subscriber counts, and per-feature transmission
      # readiness. Worth calling before a send — `readiness.broadcasts == false`
      # means the channel has no usable email server or sender identity.
      def status
        get('/api/v1/status')
      end

      # Full capability manifest: platform version, token permissions, channel
      # status, the endpoint list the token can reach, rate limit, and usage tips.
      def prime
        get('/api/v1/prime')
      end

      # Plain-text agent skill manifest (Markdown with YAML front matter),
      # including the safety rules agents are expected to follow. Returns a
      # String, not a Hash — this endpoint serves text/plain.
      def skill
        @client.request(:get, '/api/v1/skill', nil, raw: true)
      end
    end
  end
end
