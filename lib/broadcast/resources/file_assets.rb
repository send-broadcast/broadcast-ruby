# frozen_string_literal: true

module Broadcast
  module Resources
    # The channel's file library (Broadcast 2.48.0 or later): images (PNG,
    # JPEG, GIF, under 10 MB) with public URLs that never expire. Use a file's
    # `url` in emails, or as the brand kit logo:
    #
    #   file = client.file_assets.upload('logo.png')
    #   client.channel.update_design(brand: { logo_url: file['url'] })
    #
    # Requires the `file_assets_read` permission to read and
    # `file_assets_write` to upload and delete.
    class FileAssets < Base
      MAX_IDEMPOTENCY_KEY_LENGTH = 255

      CONTENT_TYPES = {
        '.png' => 'image/png',
        '.jpg' => 'image/jpeg',
        '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif'
      }.freeze

      # Files the channel can see, newest first.
      #
      #   filter:  find files by file name (closest matches first)
      #   limit:, offset:
      #
      # Returns `{ 'data' => [...], 'total' => n }`.
      def list(**params)
        get('/api/v1/file_assets', params)
      end

      def get_file_asset(id)
        get("/api/v1/file_assets/#{id}")
      end

      # Uploads a file as multipart/form-data.
      #
      # `file` is a path, or an IO (then `filename:` is required). The content
      # type follows the file extension unless `content_type:` is given.
      #
      #   channel_restricted: true links the file to this channel only
      #                       (default: every channel, as in the web app)
      #   idempotency_key:    makes a retry safe; see Transactionals#create
      def upload(file, filename: nil, content_type: nil, channel_restricted: nil, idempotency_key: nil)
        bytes, name = read_file(file, filename)
        part = FilePart.new(bytes: bytes, filename: name, content_type: content_type || content_type_for(name))

        fields = { file: part }
        fields[:channel_restricted] = channel_restricted unless channel_restricted.nil?

        @client.request(:post, '/api/v1/file_assets', fields,
                        headers: idempotency_headers(idempotency_key), multipart: true)
      end

      # Uploads base64-encoded bytes in a JSON body, for callers that already
      # hold base64 (or cannot send multipart).
      def upload_base64(filename:, data:, content_type: nil, channel_restricted: nil, idempotency_key: nil)
        payload = { filename: filename, data: data }
        payload[:content_type] = content_type unless content_type.nil?
        payload[:channel_restricted] = channel_restricted unless channel_restricted.nil?

        @client.request(:post, '/api/v1/file_assets', payload, headers: idempotency_headers(idempotency_key))
      end

      # Deletes a file. A file that is a channel's brand kit logo is refused
      # with Broadcast::ValidationError (422): choose another logo first.
      def delete(id)
        @client.request(:delete, "/api/v1/file_assets/#{id}")
      end

      private

      def read_file(file, filename)
        if file.respond_to?(:read)
          if filename.nil? && !file.respond_to?(:path)
            raise ArgumentError, 'filename: is required when uploading from an IO'
          end

          [file.read, filename || File.basename(file.path)]
        else
          path = file.to_s
          [File.binread(path), filename || File.basename(path)]
        end
      end

      def content_type_for(name)
        CONTENT_TYPES.fetch(File.extname(name.to_s).downcase, 'application/octet-stream')
      end

      def idempotency_headers(key)
        return {} if key.nil?

        key = key.to_s.strip
        return {} if key.empty?

        if key.length > MAX_IDEMPOTENCY_KEY_LENGTH
          raise ArgumentError,
                "idempotency_key must be #{MAX_IDEMPOTENCY_KEY_LENGTH} characters or fewer (got #{key.length})"
        end

        { 'Idempotency-Key' => key }
      end
    end
  end
end
