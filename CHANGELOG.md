# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed — ActionMailer delivery

Both reproduced from a real delivered message, and both traced to the same
ceiling: `Client#send_email` accepted only `to`/`subject`/`body`/`reply_to`, so
`DeliveryMethod` had no way to describe what it was sending.

- **HTML mail arrived as two nested HTML documents.** `deliver!` sent an HTML
  body without flagging it as HTML, so Broadcast recorded the send as plain text
  and wrapped the payload in its own `<html><body>` shell. `deliver!` now sends
  `html_body: true` when the mail has an `html_part`.
- **Transactional mail carried a one-click unsubscribe.** A password reset
  arrived with `List-Unsubscribe` and `List-Unsubscribe-Post: One-Click`,
  because `deliver!` could not say the send was transactional and the channel's
  unsubscribe setting applied to it. Clicking it marks the recipient
  unsubscribed, silently dropping them from every sequence and broadcast — from
  a click on a security email. `deliver!` now sends
  `include_unsubscribe_link: false` by default; set
  `include_unsubscribe_link: true` in `broadcast_settings` to opt back in. The
  option is consumed by `DeliveryMethod` rather than forwarded, since
  `Configuration` has no such attribute.

`Client#send_email` gained matching optional `html_body:` and
`include_unsubscribe_link:` keywords. Both are omitted from the payload when nil,
so direct callers of `send_email` are unaffected.

**Upgrade note.** ActionMailer deliveries change shape, not just API surface.
Mail that previously went out flagged as plain text is now flagged as HTML, and
mail that previously carried `List-Unsubscribe` no longer does. Both are the
point of the fix, but an app that relied on the unsubscribe footer appearing on
ActionMailer sends should set `include_unsubscribe_link: true` in
`broadcast_settings` to keep it.

### Documentation

The entries below are documentation only; the behaviour changes in this release
are the ActionMailer fixes above.

- **Autopilot is documented in the README.** 0.3.0 shipped the `Autopilots`
  resource with ten endpoints and no README section, so the only user-facing
  description of it was the source. Adds lifecycle, runs, the write-only
  `openrouter_api_key` guard, and the `autopilot_read` / `autopilot_write` row
  in the permissions table.
- **`SDK-COVERAGE.md` contradicted itself on Autopilot** — listed at 10/10 in
  the endpoint map and simultaneously under "Not in the API at all" with "zero
  autopilot routes". The latter was true when written and is now removed; the
  section explains what closed it, and records that autopilot sources and tone
  samples remain web-only.
- Corrected the API version header (2.19.0 → **2.20.0**) and the spec size in
  `SDK-TODO.md` (68 paths / 94 operations → **75 / 104**).
- Marked `openapi:check` in CI as done — it has been running in the self-hosted
  matrix leg but was still listed as pending.
- Documented how a **demo instance** answers: the migration API returns 403 for
  every request including valid tokens, and transactional sends are accepted
  but never delivered.

## [0.3.0] - 2026-07-26

Catches the gem up to the Broadcast v2.19 API. The API gained a response-warnings
contract, idempotency keys, and several discovery endpoints since 0.2.0; none of
them were represented here.

### Breaking
- **`host` is now required.** It previously defaulted to `https://sendbroadcast.com`,
  which 301-redirects to `sendbroadcast.net` — and since the client did not follow
  redirects, the default failed every request with
  `APIError: Unexpected response: 301`. Broadcast is self-hosted-first, so there is
  no URL the gem can guess. Pass `host:` explicitly or set `BROADCAST_HOST`.
  A host without a scheme is now rejected at construction rather than at request time.

### Added
- **`client.autopilots`** — the Autopilot API (AI-generated newsletters): CRUD,
  activate / pause / deactivate, trigger_run, and runs. The `autopilot_read` /
  `autopilot_write` token permissions existed since 2026-01-30 but had no
  endpoints behind them until Broadcast v2.19.1. `update` strips a bullet-masked
  `openrouter_api_key` so a fetch-modify-save cannot destroy the stored key.
- **API warnings.** Successful writes can carry a `warnings` array describing what
  the server ignored (`unrecognized_parameter`, `parameter_ignored`,
  `parameter_overridden`, `double_opt_in_skipped`). Exposed as `result.warnings`
  and controlled by `warnings_mode:` — `:log` (default), `:raise`, or `:ignore`.
- **`Broadcast::Response`.** All JSON calls now return a Hash subclass carrying
  `#warnings`, `#rate_limit`, `#status`, `#headers`, and `#idempotent_replay?`.
  Existing Hash-based code is unaffected.
- **Idempotent transactional sends.** `transactionals.create(..., idempotency_key:)`
  sends the `Idempotency-Key` header; `Broadcast::ConflictError` maps 409 (previously
  a generic `APIError`).
- **Rate-limit awareness.** `result.rate_limit` exposes the `X-RateLimit-*` headers,
  `RateLimitError#retry_after` exposes `Retry-After`, and 429s are now retried
  honouring it, bounded by the new `max_retry_delay` setting (default 30s).
- **Discovery endpoints:** `client.whoami`, `client.status`, `client.prime`, and
  `client.skill` (plain text).
- **Migration/export namespace:** `client.migration.*` covers all 19 read-only
  endpoints under `/api/migration/v1`, plus `each_record` for automatic paging and
  `download_file_asset` for binary assets. Requires an admin token.
- **`Broadcast::Webhook::EVENT_TYPES`** and per-category constants (`EMAIL_EVENTS`,
  `SUBSCRIBER_EVENTS`, `BROADCAST_EVENTS`, `SEQUENCE_EVENTS`, `SYSTEM_EVENTS`).
- `BROADCAST_HOST` / `BROADCAST_API_TOKEN` environment fallbacks, matching the
  Broadcast CLI's config keys.
- Redirect handling: same-host GETs follow up to 3 hops. Writes, and any redirect
  that changes host, fail with an error naming the target — every request carries
  the bearer token, so following a cross-host redirect would leak it.
- Documented attributes added to the API after 0.2.0 — template
  `template_purpose` / `confirmation_text` / `default_confirmation` /
  `confirmation_page_settings`; opt-in form `confirmation_email_template_id` /
  `welcome_email_template_id` / `confirmation_redirect_url` /
  `include_unsubscribe_link_in_confirmation`; admin-only `confirmed_at` on
  subscriber create; and the full subscriber list filter set.

### Fixed
- Debug logging redacted: SMTP passwords and provider API keys are no longer written
  to the log when `debug: true`.
- 2xx responses other than 200/201 (e.g. 204) no longer raise.
- A 2xx response with a non-JSON body no longer raises `JSON::ParserError`.
- Error messages now include ActiveModel-style `errors` hashes, not just `error` strings.
- Binary responses keep binary encoding instead of being tagged UTF-8.
- The ActionMailer delivery method no longer wraps `WarningError` in `DeliveryError` —
  the email was sent, so reporting a delivery failure would be wrong.
- **Packaging:** the gemspec shipped this repo's internal planning documents
  (`TODO.md`, `SDK-TODO.md`, `.api-coverage.yml`) and the committed `.gem`
  artifacts at the repo root to every install. The file list now excludes them,
  along with `.github/` and `pkg/`. `SDK-COVERAGE.md` is kept deliberately —
  "what does this gem support" is a user's question.

### Internal
- HTTP transport extracted from `Client` into `Broadcast::Connection`, and debug
  logging into `Broadcast::DebugLogger`.
- Test coverage for the gemspec's file list, since a wrong package fails
  silently: nothing breaks, the download is just wrong.

### Verification
- 292 tests, rubocop clean.
- Coverage against the generated OpenAPI document: 104/104 operations
  (`rake "openapi:coverage[../broadcast-ruby]"` in the `broadcast` repo).
- The built `.gem` was installed into an isolated `GEM_HOME` and exercised.
- `rake test_live` run against a real self-hosted instance: 14 tests, 52
  assertions, 0 failures. Covers the discovery endpoints, the `X-RateLimit-*`
  headers, and full create/read/update/delete round-trips for subscribers,
  sequences, segments, templates, and webhook endpoints.
- Two gaps in that run, both deliberate: the transactional **send** test is
  skipped unless `BROADCAST_TEST_EMAIL` is set, so no mail was delivered; and
  the target was a local development instance over plain HTTP, so TLS and
  real-world latency and rate limiting are still unexercised.

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
