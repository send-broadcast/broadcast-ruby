# frozen_string_literal: true

module Broadcast
  module Resources
    class Sequences < Base
      def list(**params)
        get('/api/v1/sequences', params)
      end

      def get_sequence(id, include_steps: false)
        params = include_steps ? { include_steps: true } : {}
        get("/api/v1/sequences/#{id}", params)
      end

      def create(**attrs)
        post('/api/v1/sequences', attrs)
      end

      def update(id, **attrs)
        patch("/api/v1/sequences/#{id}", attrs)
      end

      def delete(id)
        @client.request(:delete, "/api/v1/sequences/#{id}")
      end

      # --- Subscriber enrollment ---

      def add_subscriber(sequence_id, **attrs)
        post("/api/v1/sequences/#{sequence_id}/add_subscriber", attrs)
      end

      def remove_subscriber(sequence_id, email:)
        @client.request(:delete, "/api/v1/sequences/#{sequence_id}/remove_subscriber", { email: email })
      end

      def list_subscribers(sequence_id, page: 1)
        get("/api/v1/sequences/#{sequence_id}/list_subscribers", { page: page })
      end

      # --- Steps ---

      def list_steps(sequence_id)
        get("/api/v1/sequences/#{sequence_id}/steps")
      end

      def get_step(sequence_id, step_id)
        get("/api/v1/sequences/#{sequence_id}/steps/#{step_id}")
      end

      def create_step(sequence_id, **attrs)
        post("/api/v1/sequences/#{sequence_id}/steps", attrs)
      end

      def update_step(sequence_id, step_id, **attrs)
        patch("/api/v1/sequences/#{sequence_id}/steps/#{step_id}", attrs)
      end

      def move_step(sequence_id, step_id, under_id:)
        post("/api/v1/sequences/#{sequence_id}/steps/#{step_id}/move", { under_id: under_id })
      end

      def delete_step(sequence_id, step_id)
        @client.request(:delete, "/api/v1/sequences/#{sequence_id}/steps/#{step_id}")
      end
    end
  end
end
