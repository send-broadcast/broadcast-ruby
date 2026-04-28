# frozen_string_literal: true

require 'date'

module Broadcast
  module Resources
    class OptInForms < Base
      # List opt-in forms.
      #
      # NOTE: returns up to 250 results per page along with `pagination`
      # metadata. Variants are excluded (only main forms are returned).
      # Pass `page:` to advance.
      #
      # Optional filters: filter: (label substring), widget_type:, enabled: 'true'
      def list(**params)
        get('/api/v1/opt_in_forms', params)
      end

      def get_opt_in_form(id)
        get("/api/v1/opt_in_forms/#{id}")
      end

      # Create an opt-in form. Attrs are wrapped under `opt_in_form:` on the wire.
      # Nested settings hashes (theme_settings, automation_settings, security_settings,
      # trigger_settings, widget_settings) and arrays (opt_in_form_blocks_attributes,
      # opt_in_post_submission_blocks_attributes) are passed through verbatim.
      def create(**attrs)
        post('/api/v1/opt_in_forms', { opt_in_form: attrs })
      end

      def update(id, **attrs)
        patch("/api/v1/opt_in_forms/#{id}", { opt_in_form: attrs })
      end

      def delete(id)
        @client.request(:delete, "/api/v1/opt_in_forms/#{id}")
      end

      # Performance analytics for the form. start_date/end_date accept Date,
      # Time, or ISO-8601 strings (default: last 30 days).
      def analytics(id, start_date: nil, end_date: nil)
        params = {}
        params[:start_date] = coerce_date(start_date) if start_date
        params[:end_date] = coerce_date(end_date) if end_date
        get("/api/v1/opt_in_forms/#{id}/analytics", params)
      end

      def create_variant(id, name: nil, weight: nil)
        body = {}
        body[:name] = name unless name.nil?
        body[:weight] = weight unless weight.nil?
        post("/api/v1/opt_in_forms/#{id}/variants", body)
      end

      def duplicate(id, label: nil)
        body = {}
        body[:label] = label unless label.nil?
        post("/api/v1/opt_in_forms/#{id}/duplicate", body)
      end

      private

      def coerce_date(value)
        case value
        when Date, Time, DateTime then value.iso8601
        else value.to_s
        end
      end
    end
  end
end
