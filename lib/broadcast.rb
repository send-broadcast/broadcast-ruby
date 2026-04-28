# frozen_string_literal: true

require_relative 'broadcast/version'
require_relative 'broadcast/errors'
require_relative 'broadcast/configuration'
require_relative 'broadcast/client'
require_relative 'broadcast/webhook'
require_relative 'broadcast/resources/base'
require_relative 'broadcast/resources/subscribers'
require_relative 'broadcast/resources/sequences'
require_relative 'broadcast/resources/broadcasts'
require_relative 'broadcast/resources/segments'
require_relative 'broadcast/resources/templates'
require_relative 'broadcast/resources/webhook_endpoints'
require_relative 'broadcast/resources/transactionals'
require_relative 'broadcast/resources/opt_in_forms'
require_relative 'broadcast/resources/email_servers'

# ActionMailer integration — only loaded when Rails is present
if defined?(Rails::Railtie)
  require_relative 'broadcast/delivery_method'
  require_relative 'broadcast/railtie'
end

module Broadcast
end
