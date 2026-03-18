# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

rails_version = ENV.fetch('RAILS_VERSION', nil)
if rails_version
  gem 'actionmailer', "~> #{rails_version}.0"
else
  gem 'actionmailer', '>= 6.0'
end

gem 'mail', '~> 2.8'
gem 'minitest', '~> 5.0'
gem 'rake', '~> 13.0'
gem 'rubocop', '~> 1.0'
gem 'webmock', '~> 3.0'
