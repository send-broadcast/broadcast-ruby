# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-04-28

### Added
- `client.opt_in_forms` resource: list, get, create, update, delete, analytics, create_variant, duplicate
- `client.email_servers` resource: list, get, create, update, delete, test_connection, copy_to_channel
- `client.transactionals` resource with full create surface (`template_id`, `preheader`, `include_unsubscribe_link`, `subscriber:` attrs); `client.send_email` and `client.get_email` are now thin shims that delegate
- Double opt-in support: pass `double_opt_in: true` (or a hash with `reply_to:` / `confirmation_template_id:` / `include_unsubscribe_link:`) to `transactionals.create` and `subscribers.create`. Optional top-level `confirmation_template_id:` is also accepted
- `Configuration#broadcast_channel_id` plus `client.with_channel(id) { ... }` block API for admin/system tokens — auto-includes the channel on every request inside the block (or globally when set on config), without overriding callers that pass it explicitly
- `Broadcast::AuthorizationError` for 403 responses (previously fell through to a generic `APIError`)
- Credential redaction scrubber on `email_servers.update`: values matching the API's bullet-redaction shape on known credential fields are stripped from the payload (with a logger warning) so callers can't accidentally round-trip a redacted response back into the model

### Notes
- `opt_in_forms.list` returns up to 250 results per page with `pagination` metadata; only main forms are returned (variants are excluded)
- `opt_in_forms` `index`/`show` JSON shape (rendered via JBuilder views) differs slightly from `create`/`update` (rendered via the controller's inline serializer)
- `email_servers.copy_to_channel` requires an admin token and is account-scoped in SaaS mode

## [0.1.4] - 2026-03-18

### Fixed
- Register delivery method at class load time instead of in an initializer. ActionMailer's railtie applies config settings (including `broadcast_settings`) inside `on_load(:action_mailer)`, which ran before our initializer-based registration. This caused `undefined method broadcast_settings=` on boot in Rails 8.1.

## [0.1.3] - 2026-03-18

### Fixed
- Attempted fix for Railtie timing: use `before: :load_config_initializers`. Did not fully resolve the issue — superseded by 0.1.4.

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
