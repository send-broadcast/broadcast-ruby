# frozen_string_literal: true

module Broadcast
  module Resources
    # Autopilot — AI-generated newsletters.
    #
    # Requires the `autopilot_read` / `autopilot_write` token permissions.
    class Autopilots < Base
      # The API renders a configured key bullet-masked and never returns the
      # real value. Writing a masked value back would replace a working
      # credential with bullets, so it is stripped — same guard as
      # EmailServers#update.
      REDACTED_KEY_PATTERN = /\A•+\z/

      def list(**params)
        get('/api/v1/autopilots', params)
      end

      def get_autopilot(id)
        get("/api/v1/autopilots/#{id}")
      end

      # Create an autopilot. Attrs are wrapped under `autopilot:` on the wire.
      #
      #   name:                  required, unique per channel
      #   openrouter_api_key:    OpenRouter credential (write-only)
      #   ai_model:              e.g. 'openai/gpt-4o'
      #   schedule_frequency:    'daily' | 'weekly' | 'biweekly' | 'monthly'
      #   schedule_day_of_week:, schedule_day_of_month:, schedule_time:, schedule_timezone:
      #   copies_to_generate:    how many drafts each run produces
      #   tone_description:, content_instructions:, newsletter_structure:
      #   segment_ids:           array — restrict the newsletter's audience
      def create(**attrs)
        post('/api/v1/autopilots', { autopilot: attrs })
      end

      # Update an autopilot. A bullet-masked openrouter_api_key is dropped
      # before sending; pass the real key to rotate it, or omit the field.
      def update(id, **attrs)
        patch("/api/v1/autopilots/#{id}", { autopilot: scrub_redacted_key(attrs) })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/autopilots/#{id}")
      end

      # --- Lifecycle ---

      # Activate the autopilot so it runs on its schedule.
      #
      # Requires at least one active source, an API key, and a model. Raises
      # Broadcast::ValidationError naming the missing prerequisites otherwise.
      def activate(id)
        post("/api/v1/autopilots/#{id}/activate")
      end

      def pause(id)
        post("/api/v1/autopilots/#{id}/pause")
      end

      def deactivate(id)
        post("/api/v1/autopilots/#{id}/deactivate")
      end

      # Queue a generation run now. Returns 202 with the created run — the work
      # is asynchronous, so poll `runs` for progress rather than expecting a
      # finished newsletter here.
      def trigger_run(id)
        post("/api/v1/autopilots/#{id}/trigger_run")
      end

      # --- Runs ---

      # Generation runs, most recent first. Supports limit: and offset:.
      def runs(id, **params)
        get("/api/v1/autopilots/#{id}/runs", params)
      end

      private

      def scrub_redacted_key(attrs)
        key = attrs[:openrouter_api_key] || attrs['openrouter_api_key']
        return attrs unless key.is_a?(String) && key.match?(REDACTED_KEY_PATTERN)

        warn_redacted
        attrs.reject { |name, _| name.to_sym == :openrouter_api_key }
      end

      def warn_redacted
        msg = '[broadcast-ruby] Dropped redacted openrouter_api_key from update payload — ' \
              'pass the real key or omit the field'
        if @client.config.logger
          @client.config.logger.warn(msg)
        else
          Kernel.warn(msg)
        end
      end
    end
  end
end
