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

      # This installation's own OpenAPI document, as YAML. Returns a String,
      # not a Hash — the endpoint serves application/yaml.
      #
      # The server URL in the document is rewritten by the installation to the
      # host that served it, so the result feeds a client generator or an API
      # explorer without hand-editing. Worth preferring over a spec copied from
      # anywhere else: a 2.28 install serves the 2.28 surface, so the document
      # cannot drift from the routes it describes.
      def openapi
        @client.request(:get, '/api/v1/openapi', nil, raw: true)
      end
    end
  end
end
