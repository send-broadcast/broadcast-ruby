# frozen_string_literal: true

module Broadcast
  module Resources
    class Base
      def initialize(client)
        @client = client
      end

      private

      def get(path, params = {})
        @client.request(:get, path, params)
      end

      def post(path, body = {})
        @client.request(:post, path, body)
      end

      def patch(path, body = {})
        @client.request(:patch, path, body)
      end
    end
  end
end
