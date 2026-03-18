# frozen_string_literal: true

require_relative 'lib/broadcast/version'

Gem::Specification.new do |spec|
  spec.name = 'broadcast-ruby'
  spec.version = Broadcast::VERSION
  spec.authors = ['Simon Chiu']
  spec.email = ['simon@furvur.com']

  spec.summary = 'Ruby client for the Broadcast email platform'
  spec.description = 'Full API client for Broadcast. Subscribers, sequences, broadcasts, segments, ' \
                     'templates, webhooks, and transactional email. Works with any Broadcast instance.'
  spec.homepage = 'https://github.com/furvur/broadcast-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/furvur/broadcast-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/furvur/broadcast-ruby/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ .git])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'base64'
end
