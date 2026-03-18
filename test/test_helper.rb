# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'broadcast'

require 'minitest/autorun'
require 'webmock/minitest'

WebMock.disable_net_connect!(allow_localhost: true)

HOST = 'https://broadcast.test'

def new_client(**overrides)
  Broadcast::Client.new(api_token: 'test-token', host: HOST, retry_attempts: 1, **overrides)
end
