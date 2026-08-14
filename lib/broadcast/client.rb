# frozen_string_literal: true

module Broadcast
  class Client
    CHANNEL_OVERRIDE_KEY = :__broadcast_ruby_channel_override

    attr_reader :config

    def initialize(**settings)
      @config = Configuration.new
      settings.each { |k, v| @config.public_send(:"#{k}=", v) }
      @config.validate!
      @connection = Connection.new(@config)
    end

    # --- Channel scoping (admin/system tokens) ---

    # Run a block with a temporary broadcast_channel_id override that will be
    # auto-included on every request inside the block. Useful for admin/system
    # tokens that need to scope each call to a specific channel.
    #
    #   client.with_channel(123) do
    #     client.email_servers.list
    #   end
    def with_channel(broadcast_channel_id)
      key = channel_override_key
      previous = Thread.current[key]
      Thread.current[key] = broadcast_channel_id
      yield self
    ensure
      Thread.current[key] = previous
    end

    # --- Transactional email (convenience shims) ---

    # Thin convenience wrapper around `transactionals.create`. Use
    # `client.transactionals.create` directly for template_id, double_opt_in,
    # preheader, idempotency_key, and other advanced options.
    # `html_body` tells Broadcast the body is already HTML. Without it the send
    # is recorded as plain text and the payload is wrapped in Broadcast's own
    # <html><body> shell, so an HTML mail arrives as two nested documents.
    #
    # `include_unsubscribe_link` lets the caller suppress the unsubscribe
    # footer and List-Unsubscribe header. Transactional mail wants that off: a
    # one-click unsubscribe on a password reset marks the person unsubscribed
    # and silently drops them from every sequence and broadcast.
    def send_email(to:, subject: nil, body: nil, reply_to: nil,
                   html_body: nil, include_unsubscribe_link: nil)
      opts = { to: to, subject: subject, body: body, reply_to: reply_to }
      opts[:html_body] = html_body unless html_body.nil?
      opts[:include_unsubscribe_link] = include_unsubscribe_link unless include_unsubscribe_link.nil?

      transactionals.create(**opts)
    end

    def get_email(id)
      transactionals.get_transactional(id)
    end

    # --- Discovery (convenience shims) ---

    def whoami
      discovery.whoami
    end

    def status
      discovery.status
    end

    def prime
      discovery.prime
    end

    def skill
      discovery.skill
    end

    # --- Resource sub-clients ---

    def subscribers
      @subscribers ||= Resources::Subscribers.new(self)
    end

    def sequences
      @sequences ||= Resources::Sequences.new(self)
    end

    def broadcasts
      @broadcasts ||= Resources::Broadcasts.new(self)
    end

    def segments
      @segments ||= Resources::Segments.new(self)
    end

    def templates
      @templates ||= Resources::Templates.new(self)
    end

    def webhook_endpoints
      @webhook_endpoints ||= Resources::WebhookEndpoints.new(self)
    end

    def transactionals
      @transactionals ||= Resources::Transactionals.new(self)
    end

    def opt_in_forms
      @opt_in_forms ||= Resources::OptInForms.new(self)
    end

    def email_servers
      @email_servers ||= Resources::EmailServers.new(self)
    end

    def autopilots
      @autopilots ||= Resources::Autopilots.new(self)
    end

    def discovery
      @discovery ||= Resources::Discovery.new(self)
    end

    # The current channel's suppression list (plus `check`, which reads the
    # global list too).
    def suppressions
      @suppressions ||= Resources::Suppressions.new(self)
    end

    # The installation-wide suppression list. Requires an admin (system) API
    # token.
    def global_suppressions
      @global_suppressions ||= Resources::GlobalSuppressions.new(self)
    end

    # Read-only export endpoints under /api/migration/v1. Requires an admin
    # (system) API token.
    def migration
      @migration ||= Resources::Migration.new(self)
    end

    # @api private
    def request(method, path, body_or_params = nil, headers: {}, raw: false)
      payload = inject_channel_scope(body_or_params)
      @connection.request(method, path, payload, headers: headers, raw: raw)
    end

    private

    def channel_override_key
      :"#{CHANNEL_OVERRIDE_KEY}_#{object_id}"
    end

    def active_channel_id
      Thread.current[channel_override_key] || @config.broadcast_channel_id
    end

    # Auto-include broadcast_channel_id in request payload when configured (or
    # set via with_channel) and not already specified by the caller.
    def inject_channel_scope(body_or_params)
      channel_id = active_channel_id
      return body_or_params if channel_id.nil?

      payload = body_or_params.is_a?(Hash) ? body_or_params.dup : {}
      return payload if payload[:broadcast_channel_id] || payload['broadcast_channel_id']

      payload[:broadcast_channel_id] = channel_id
      payload
    end
  end
end
