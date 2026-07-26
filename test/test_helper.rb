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

# Temporarily sets (or with a nil value, unsets) environment variables for the
# duration of the block, restoring whatever was there before. Configuration
# reads BROADCAST_HOST/BROADCAST_API_TOKEN at construction, so tests that care
# about defaults must not inherit the developer's shell.
def with_env(vars)
  original = vars.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
  vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  yield
ensure
  original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
end
