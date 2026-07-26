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
  spec.homepage = 'https://github.com/send-broadcast/broadcast-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/send-broadcast/broadcast-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/send-broadcast/broadcast-ruby/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Internal to this repo — roadmaps, work logs, and the manifest the coverage
  # tooling in the broadcast repo reads. Useful here, noise in someone's
  # vendor/bundle. SDK-COVERAGE.md is kept: it answers "what does this gem
  # actually support?", which is a user's question.
  internal_files = %w[TODO.md SDK-TODO.md .api-coverage.yml .rubocop.yml]

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        internal_files.include?(f) ||
        f.end_with?('.gem') ||
        f.start_with?(*%w[bin/ test/ pkg/ .git .github])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'base64'
end
