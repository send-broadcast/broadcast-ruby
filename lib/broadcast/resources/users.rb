# frozen_string_literal: true

module Broadcast
  module Resources
    # Manage installation users, their per-channel permissions, and their
    # system-wide permissions. **Requires an admin API token** — a regular
    # channel token gets `Broadcast::AuthorizationError`
    # ("Admin API token required for user management").
    #
    # Sudo users are read-only through this API: `update`, `deactivate`,
    # `activate`, `delete`, and any permission write against a sudo user
    # raise `Broadcast::AuthorizationError`
    # ("Sudo users cannot be changed through the API"). Sudo access can never
    # be granted through this resource.
    class Users < Base
      # rubocop:disable Naming/MethodParameterName -- `q` matches the API's own query param name
      def list(limit: nil, offset: nil, q: nil, status: nil)
        # rubocop:enable Naming/MethodParameterName
        params = {}
        params[:limit] = limit unless limit.nil?
        params[:offset] = offset unless offset.nil?
        params[:q] = q unless q.nil?
        params[:status] = status unless status.nil?
        get('/api/v1/users', params)
      end

      def get_user(id)
        get("/api/v1/users/#{id}")
      end

      def create(**attrs)
        post('/api/v1/users', { user: attrs })
      end

      # Update a user. Attrs are wrapped under `user:` on the wire. Raises
      # `Broadcast::AuthorizationError` if the target user is a sudo user.
      def update(id, **attrs)
        patch("/api/v1/users/#{id}", { user: attrs })
      end

      def deactivate(id)
        post("/api/v1/users/#{id}/deactivate")
      end

      # Reactivates the user and also clears any lockout.
      def activate(id)
        post("/api/v1/users/#{id}/activate")
      end

      def delete(id)
        @client.request(:delete, "/api/v1/users/#{id}")
      end

      def channel_permissions(id)
        get("/api/v1/users/#{id}/channel_permissions")
      end

      # Set a user's permissions for one channel. This is a PUT: it REPLACES
      # the whole channel permission record, so any flag not named under
      # `permissions:` becomes false. Pass exactly one of `permissions:`,
      # `role:`, or `preset_id:` — anything else raises `ArgumentError`
      # client-side before a request is made. Sudo can never be granted this
      # way, and doing so is rejected server-side.
      def set_channel_permissions(id, broadcast_channel_id, permissions: nil, role: nil, preset_id: nil)
        body = exactly_one_option!(permissions: permissions, role: role, preset_id: preset_id)
        @client.request(:put, "/api/v1/users/#{id}/channel_permissions/#{broadcast_channel_id}", body)
      end

      def remove_channel_permissions(id, broadcast_channel_id)
        @client.request(:delete, "/api/v1/users/#{id}/channel_permissions/#{broadcast_channel_id}")
      end

      # Apply the same permissions|role|preset_id (exactly one, same rule as
      # `set_channel_permissions`) to several channels at once. Returns
      # `applied` and `failed` (per-channel errors), rather than raising, for
      # channels that could not be updated.
      def bulk_channel_permissions(id, broadcast_channel_ids:, permissions: nil, role: nil, preset_id: nil)
        body = exactly_one_option!(permissions: permissions, role: role, preset_id: preset_id)
        body[:broadcast_channel_ids] = broadcast_channel_ids
        post("/api/v1/users/#{id}/channel_permissions/bulk", body)
      end

      def system_permissions(id)
        get("/api/v1/users/#{id}/system_permissions")
      end

      # Updates only the flags named in `permissions` -- unnamed flags are
      # left as-is. `sudo_access` is never accepted; sending it is a 422.
      def update_system_permissions(id, permissions)
        patch("/api/v1/users/#{id}/system_permissions", { permissions: permissions })
      end

      private

      def exactly_one_option!(permissions:, role:, preset_id:)
        given = { permissions: permissions, role: role, preset_id: preset_id }.compact
        raise ArgumentError, 'Pass exactly one of permissions:, role:, or preset_id:' unless given.size == 1

        given
      end
    end
  end
end
