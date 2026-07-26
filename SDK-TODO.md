# Broadcast SDK roadmap

Which client libraries to build, in what order, and what "feature parity"
concretely means for each. `broadcast-ruby` is the reference implementation —
its per-release work is tracked in [TODO.md](TODO.md).

> Lives in this repo because Ruby is the reference SDK. If the roadmap starts
> driving work in other repos, move it to `broadcast` (the product repo) and
> leave a pointer here.

---

## Build order

### 1. TypeScript / Node — `@broadcast/sdk`

Highest priority, for two reasons that have nothing to do with ecosystem size.

**We are already shipping docs for it.** `docs/agents-mcp.html.markerb` on
sendbroadcast.net tells users to run `npx -y @broadcast/mcp-server`. That
package returns 404 on the npm registry. Anyone following the published MCP
setup guide today hits a dead end. Either build it or pull the page.

**Every comparable product leads with Node.** Resend, Postmark, and Loops all
publish a TypeScript SDK first. A Ruby-only client makes Broadcast read like a
Rails side-project rather than a platform, regardless of how good the API is.

- [ ] Full parity matrix (below)
- [ ] Real types for resource payloads, not `Record<string, unknown>`
- [ ] ESM + CJS dual build; Node 18+ (native `fetch`, `AbortController`)
- [ ] Edge-runtime safe (no `node:crypto` in the hot path except webhook verify)

### 2. MCP server — `@broadcast/mcp-server`

Related to #1 but strategically distinct, and arguably the higher-leverage one.
The app has already built the agent-facing groundwork:

| Piece | Where |
|---|---|
| `GET /api/v1/prime` | capability manifest, per-token, with endpoint list |
| `GET /api/v1/skill` | plain-text agent skill incl. explicit safety rules |
| `GET /api/v1/whoami` | token identity and permission introspection |
| Bash CLI | served from `/agents/cli`, config at `~/.config/broadcast/config` |
| Setup links | `/agents/setup/:slug` |

Everything is in place except the MCP binary itself. Build it on the Node SDK.

- [ ] Tools derived from `prime`'s capability map, gated by real token permissions
- [ ] Honour the safety rules already written into `/api/v1/skill` — in
      particular: never send a broadcast without explicit confirmation
- [ ] Auto-discover credentials from `~/.config/broadcast/config` (the docs
      already promise this)
- [ ] Make the published docs page true

### 3. PHP — `broadcast/broadcast-php`

This is a distribution decision more than an SDK decision. Email-marketing
buyers skew heavily WordPress, and a PHP SDK is the prerequisite for a
WordPress plugin (opt-in form embedding + subscriber sync), which is a real
acquisition channel rather than a convenience. Laravel support comes along for
free.

- [ ] PSR-18 HTTP client, PSR-3 logging
- [ ] Composer package, PHP 8.1+
- [ ] Then: WordPress plugin on top of it (separate repo, separate roadmap)

### 4. Python — `broadcast-python`

Django/FastAPI apps, plus the "nightly script that syncs our CRM" crowd.
Straightforward, steady demand, no strategic angle beyond coverage.

- [ ] Sync client first; async (`httpx`) second
- [ ] Type hints throughout, `py.typed` marker

### 5. Go — deferred

The self-hosting audience is the Go-shaped one, but it's also the audience most
comfortable calling the REST API directly. Revisit if support requests
materialise.

---

## Parity matrix

Every SDK ships all of this before it is announced. A client that covers the
resources but skips the transport column below is the situation Ruby is in
right now — it looks complete and quietly loses information.

### Transport

| Capability | Why |
|---|---|
| Required explicit `host` | Broadcast is self-hosted-first; there is no sensible default |
| `BROADCAST_HOST` / `BROADCAST_API_TOKEN` env fallback | matches the CLI config keys |
| Bearer auth | `Authorization: Bearer <token>` |
| `User-Agent: broadcast-<lang>/<version>` | server-side client attribution |
| **`warnings` array surfaced** | 2xx responses carry ignored-parameter warnings |
| **`Idempotency-Key` request header** | transactional sends |
| **`Idempotency-Replayed` response header** | tells the caller it was a replay |
| **Rate-limit headers** | `X-RateLimit-Limit` / `-Remaining` / `-Reset` |
| **429 retry honouring `Retry-After`** | bounded by a max-delay setting |
| Retry on timeout + 5xx with backoff | |
| Typed errors | 401/403/404/409/422/429/5xx each distinct |
| Redirect handling | follow on GET, explain-and-fail on writes |
| Raw/text response path | `GET /api/v1/skill` is `text/plain` |
| Channel scoping | `broadcast_channel_id` for admin/system tokens |
| Debug logging | request/response, credentials redacted |

### Resources

| Resource | Operations |
|---|---|
| Subscribers | list (8 filters), find, create (incl. `confirmed_at` for admin tokens), update, add/remove tag, activate, deactivate, subscribe, unsubscribe, resubscribe, redact |
| Broadcasts | CRUD, send, schedule, cancel schedule, statistics, statistics timeline, statistics links |
| Sequences | CRUD, add/remove/list subscribers, step CRUD, move step |
| Segments | CRUD (nested groups + rules) |
| Templates | CRUD incl. `template_purpose`, `confirmation_text`, `default_confirmation`, `confirmation_page_settings` |
| Opt-in forms | CRUD, analytics, create variant, duplicate, confirmation/welcome template ids |
| Email servers | CRUD, test connection, copy to channel, **credential-redaction guard** |
| Webhook endpoints | CRUD, test, deliveries |
| Transactionals | create (template, double opt-in, idempotency), show |
| Discovery | whoami, status, prime, skill |
| Migration | 19 read-only export endpoints under `/api/migration/v1` |

### Webhooks (inbound)

| Capability |
|---|
| HMAC-SHA256 verification, `v1,<base64>` header format |
| 5-minute timestamp tolerance, constant-time compare |
| `EVENT_TYPES` constant (30+ values) |

### Non-negotiables

- **Credential redaction guard.** The API returns credential fields
  bullet-masked. `broadcast-ruby`'s `EmailServers#scrub_redacted` strips
  redacted values out of update payloads so a naive fetch-modify-save can't
  overwrite a real SMTP password with `••••••••`. Every SDK needs this — it is
  a data-loss bug waiting to happen, not a nicety.
- **Never log credentials or subscriber emails** at debug level.
- Test suite with mocked HTTP + a live smoke test gated behind an env var.

---

## Cross-cutting: the OpenAPI spec — **built**

Four things describe the same endpoints — this gem, the bash CLI, the docs site,
and the not-yet-existent MCP server. The v2.19 warnings work landed in the app
and reached none of the others; that was the drift made visible.

The spec now generates from the code. It lives in the `broadcast` repo:

| Path | What |
|---|---|
| `lib/openapi/spec_builder.rb` | Generates OpenAPI 3.1 from `config/routes.rb` + `*_PARAM_KEYS` / `KNOWN_TOP_LEVEL_KEYS` |
| `lib/openapi/coverage_report.rb` | Scores a client library against the spec |
| `openapi/overlay.yml` | Hand-written descriptions, response schemas, query params |
| `openapi/broadcast-api.yaml` | Generated output — 68 paths, 94 operations |

```bash
bin/rails openapi:generate                    # rebuild the spec
bin/rails openapi:check                       # CI guard: fails when stale
bin/rails "openapi:coverage[../broadcast-ruby]"
```

Design notes worth keeping in mind when extending it:

- **The router is the source of truth.** The overlay refines operations but
  cannot invent one — an `operationId` with no matching route is ignored. That
  asymmetry is what stops the spec drifting into fiction.
- **Response schemas are not derived.** Controllers build them in hand-written
  `*_json` methods and JBuilder views; parsing those would be guesswork. They
  come from the overlay, and that is the biggest remaining gap in the spec.
- **The spec is identical in self-host and SaaS mode** — verified, not assumed.
  The `/api` routes sit outside the mode conditional.
- **Clients declare metaprogrammed endpoints** in `.api-coverage.yml`. Without
  it, a client that generates 18 methods from an array scores worse than one
  that copy-pastes them 18 times.

### Next steps for it

- [ ] Wire `openapi:check` into CI — the guard is worthless unmerged
- [ ] Fill in response schemas in the overlay, resource by resource
- [ ] Generate the Node SDK's types from the spec rather than hand-writing them
- [ ] Derive MCP tool schemas from it (compare against `prime`'s `CAPABILITY_MAP`,
      which is a hand-maintained version of the same information)
- [ ] Publish it — a downloadable `broadcast-api.yaml` lets customers generate
      clients in languages we will never ship
