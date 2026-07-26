# broadcast-ruby — catch up to the v2.19 API

Branch: `sdk-parity-0.3.0` → releases as **v0.3.0**

The gem was last aligned with the API on 2026-04-28 (v0.2.0). Since then the
Broadcast app added a response-warnings contract, idempotency keys, several
discovery endpoints, and a batch of new resource attributes. This file tracks
closing that gap. Cross-language roadmap lives in [SDK-TODO.md](SDK-TODO.md).

Source of truth for every claim below: `Projects/Furvur/broadcast` (API) and
`Projects/Furvur/send-broadcast/app/content/pages/docs` (published docs).

**Status: implemented.** 263 tests green, rubocop clean. Not yet done:
`rake test_live` against a real instance (needs a token + host), and the
release itself (tag, `gem build`, push). Live tests were extended to cover the
new discovery endpoints and to assert the `X-RateLimit-*` headers still arrive.

---

## 1. Broken today — fix first

- [x] **Default host is wrong and unreachable.** `configuration.rb:17` defaults
      to `https://sendbroadcast.com`, which 301s to `sendbroadcast.net`.
      `Client#execute` uses bare `Net::HTTP` and does not follow redirects, so
      the default produces `APIError: Unexpected response: 301` on the first
      call. Broadcast is self-hosted-first — the docs always say
      `https://your-broadcast-instance.com`, and `sendbroadcast.net` is the
      licensing/upstream API (`engines/broadcast_saas/.../configuration.rb:27`),
      not a customer API host. **There is no correct default.**
      - [x] Remove the default; require `host` (raise `ConfigurationError` with
            a message that names the fix).
      - [x] Fall back to `BROADCAST_HOST` / `BROADCAST_API_TOKEN` env vars,
            matching the CLI's `~/.config/broadcast/config` keys.
      - [x] Follow redirects on GET (max 3 hops); on non-GET raise an
            `APIError` that names the `Location` so a misconfigured host is
            self-diagnosing rather than mysterious.
      - [x] Fix the 6 `sendbroadcast.com` references in README.

- [x] **The `warnings` contract is silently dropped.** Commits `0d694f1b` and
      `a2766eb5` (2026-07-22) added `ApiResponseWarnings` to every v1 write
      endpoint. Successful 2xx responses now carry a `warnings` array
      (`unrecognized_parameter`, `parameter_ignored`, `parameter_overridden`,
      `double_opt_in_skipped`). The entire point is telling clients a parameter
      was ignored; the gem returns the parsed Hash and the user never sees it.

## 2. Client / transport layer

- [x] **`Broadcast::Response`** — return value that still behaves like the
      parsed Hash (subclass `Hash`, so `result['id']`, `is_a?(Hash)`, and
      `assert_equal` all keep working) plus `#warnings`, `#rate_limit`,
      `#status`, `#headers`, `#idempotent_replay?`.
      Non-Hash JSON bodies (arrays) pass through unwrapped.
- [x] **Warning surfacing** — `config.warnings_mode`: `:log` (default, needs
      `logger`), `:raise` (`Broadcast::WarningError`), `:ignore`.
- [x] **`Idempotency-Key`** (`93f7b1d1`, 2026-07-22) — the client cannot send
      any custom header today.
      - [x] `Client#request(..., headers: {})`
      - [x] `transactionals.create(..., idempotency_key:)`
      - [x] Map **409** → new `Broadcast::ConflictError` (in-flight replay).
            Today it falls through to a generic `APIError`.
      - [x] Surface `Idempotency-Replayed: true` as `Response#idempotent_replay?`
      - [x] Note the 422 case: same key + different payload is a *different*
            error than a validation failure. Document it.
- [x] **Rate limits** — every response carries `X-RateLimit-Limit/Remaining/Reset`
      (`api/v1/base_controller.rb:20`) and 429s carry `Retry-After`
      (`rack_attack.rb:100`). The gem reads none of them and
      `retry_with_backoff` only retries timeouts and 5xx.
      - [x] `Response#rate_limit` (limit, remaining, reset)
      - [x] `RateLimitError#retry_after`
      - [x] Retry 429 honouring `Retry-After`, bounded by new
            `config.max_retry_delay` (default 30s) so a long server-side window
            can't hang the caller.
- [x] **Raw/text responses** — `GET /api/v1/skill` returns `text/plain`.
      `handle_response` unconditionally `JSON.parse`s. Needs a raw path.

## 3. Endpoints with zero coverage

- [x] **Discovery** (`Resources::Discovery`, delegated on `Client`)
      - [x] `GET /api/v1/whoami` — token type, permissions, resolved channel
      - [x] `GET /api/v1/status` — readiness for broadcasts/sequences/transactionals
      - [x] `GET /api/v1/prime` — capability manifest + rate limit + tips
      - [x] `GET /api/v1/skill` — plain-text agent skill manifest (raw path)
- [x] **Migration namespace** (`client.migration.*`) — 19 read-only admin
      endpoints under `/api/migration/v1`, entirely unrepresented. This is the
      backup/export surface: `manifest`, `channels`, `subscribers`, `templates`,
      `segments`, `sequences`, `email_servers`, `opt_in_forms`, `broadcasts`,
      `outbound_receipts`, `webhook_endpoints`, `tokens`, `suppressions`,
      `tags`, `users`, `link_redirects`, `link_clicks`, `subscriber_histories`,
      `file_assets` (+ `file_assets/:id/download`).

## 4. Attribute drift (all landed after v0.2.0)

These pass through `**attrs` today, so they "work" — but they're undocumented,
untested, and a user who guesses the wrong name now gets a silent
`unrecognized_parameter` warning the gem also swallows.

- [x] **Templates** (`31aa3515`) — `template_purpose`, `confirmation_text`,
      `default_confirmation`, nested `confirmation_page_settings`
      (per-state `heading`/`body`).
- [x] **Opt-in forms** (`543c0976`, `31aa3515`, `3e30d9eb`) —
      `confirmation_email_template_id`, `welcome_email_template_id`,
      `confirmation_redirect_url`, `include_unsubscribe_link_in_confirmation`,
      multi-line custom fields.
- [x] **Subscribers `create`** (`93f7b1d1`) — `confirmed_at`, permitted only for
      admin/migration tokens (`subscribers_controller.rb:498`).
- [x] **Subscribers `list`** — document the real filter set: `is_active`,
      `source`, `created_after`, `created_before`, `tags[]`, `email` (partial
      match), `confirmation_status` (`confirmed`/`unconfirmed`),
      `custom_data{}` (JSONB containment).
- [x] **Webhooks** — add `Broadcast::Webhook::EVENT_TYPES` from
      `WebhookEndpoint::AVAILABLE_EVENT_TYPES` (30+ values across `email.*`,
      `subscriber.*`, `broadcast.*`, `sequence.*`). Signature verification is
      already correct; there's just no way to discover valid event names.

## 5. Release

- [x] Version → `0.3.0`
- [x] CHANGELOG entry, calling out the **breaking** `host` change
- [x] README: warnings, idempotency, rate limits, discovery, migration,
      drifted attributes
- [x] `rubocop` clean, full `rake test` green

---

## Known non-goals

- Autopilot, Ask AI, subscriber imports, and CSV export have no public v1 API —
  they're web-UI only. Nothing to wrap.
- `bulk_archive` / `export` on broadcasts are web routes, not API routes.

## Follow-up worth discussing

Four clients now describe the same endpoints — this gem, the bash CLI served
from `/agents/cli`, the docs site, and (per `agents-mcp` docs) an MCP server
that doesn't exist yet. The July warnings work is evidence the drift is real
and ongoing. Generating an OpenAPI spec from `config/routes.rb` plus the
`*_PARAM_KEYS` constants would make the next three SDKs cheaper than this one.
See SDK-TODO.md.
