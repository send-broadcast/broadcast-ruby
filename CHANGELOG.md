# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2] - 2026-03-18

### Added
- ActionMailer delivery method and Rails Railtie for seamless Rails integration
- ActionMailer end-to-end integration tests with a real mailer class
- `User-Agent: broadcast-ruby/VERSION` header on all API requests
- `Broadcast::DeliveryError` for ActionMailer error wrapping
- `lib/broadcast-ruby.rb` shim so Bundler auto-requires correctly (no `require:` needed in Gemfile)
- GitHub Actions CI: Ruby 3.2-4.0 x Rails 7.1-8.1 matrix
- RuboCop linting in CI
- Comprehensive README: token setup, permissions table, migration guide, webhook controller example, troubleshooting
- `.github/secret_scanning.yml` for secret leak prevention

### Fixed
- Templates `create`/`update` now correctly wrap params under `template` key
- Trailing slash on `host` is stripped to prevent double-slash URLs
- GET requests no longer log a spurious "Body: {}" in debug mode

### Removed
- Dead `Broadcast.configure` global singleton (was disconnected from Client)

## [0.1.1] - 2026-03-18

### Added
- ActionMailer delivery method (`Broadcast::DeliveryMethod`)
- Rails Railtie for auto-registering `:broadcast` delivery method
- `User-Agent` header on all requests
- `Broadcast::DeliveryError` error class
- `Broadcast::NotFoundError` for 404 responses

### Fixed
- Strip trailing slash from `host` configuration
- Templates API wrapping under `template` key

## [0.1.0] - 2026-03-17

### Added
- Initial release
- `Broadcast::Client` with keyword arg construction and eager validation
- Transactional email: `send_email`, `get_email`
- Subscribers: list, find, create, update, add/remove tags, deactivate, activate, unsubscribe, resubscribe, redact
- Sequences: CRUD, subscriber enrollment, step management (14 methods)
- Broadcasts: CRUD, send, schedule, cancel, statistics (11 methods)
- Segments: list, get, create, update, delete
- Templates: list, get, create, update, delete
- Webhook Endpoints: list, get, create, update, delete, test, deliveries
- `Broadcast::Webhook.verify` for HMAC-SHA256 signature verification
- Automatic retry with linear backoff on server errors (5xx) and timeouts
- Debug logging with configurable logger
- Thread-safe configuration
- Full test suite: 108 unit tests + 9 live integration tests
