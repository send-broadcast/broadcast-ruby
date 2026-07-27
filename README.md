# broadcast-ruby

Ruby client for the [Broadcast](https://sendbroadcast.net) email platform.

Works with any Broadcast instance — self-hosted or SaaS.

## Installation

Add to your Gemfile:

```ruby
gem 'broadcast-ruby'
```

For plain Ruby scripts (non-Rails):

```ruby
require 'broadcast'
```

## Getting Your API Token

1. Log in to your Broadcast dashboard
2. Go to **Settings > API Keys**
3. Click **New API Key**
4. Name it, select the permissions you need (see [Permissions](#api-token-permissions) below), and save
5. Copy the token

## Quick Start

**In a Rails app?** Jump to [Rails ActionMailer Integration](#rails-actionmailer-integration) -- you don't need to use the client directly.

**In a plain Ruby script or non-Rails app?** Use the client:

```ruby
require 'broadcast'

client = Broadcast::Client.new(
  api_token: 'your-token',
  host: 'https://mail.example.com'  # your Broadcast instance
)

client.send_email(
  to: 'jane@example.com',
  subject: 'Welcome!',
  body: '<h1>Hello Jane</h1><p>Welcome aboard.</p>'
)
```

`host` has no default — every Broadcast instance lives at its own domain, so
there is no URL the gem could guess correctly. You can supply it through the
environment instead, using the same variable names as the Broadcast CLI:

```bash
export BROADCAST_HOST=https://mail.example.com
export BROADCAST_API_TOKEN=your-token
```

```ruby
client = Broadcast::Client.new  # picks both up from ENV
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `api_token` | *required* | Your Broadcast API token. Falls back to `BROADCAST_API_TOKEN` |
| `host` | *required* | Broadcast instance URL, scheme included. Falls back to `BROADCAST_HOST` |
| `timeout` | `30` | Read timeout (seconds) |
| `open_timeout` | `10` | Connection timeout (seconds) |
| `retry_attempts` | `3` | Max total attempts (1 initial + 2 retries). Server errors (5xx), timeouts, and rate limits (429) are retried; other client errors (4xx) are not |
| `retry_delay` | `1` | Base delay between retries in seconds (multiplied by attempt number) |
| `max_retry_delay` | `30` | Ceiling for a server-supplied `Retry-After`, so a long rate-limit window can't stall the caller |
| `warnings_mode` | `:log` | How to handle API warnings — `:log`, `:raise`, or `:ignore`. See [API Warnings](#api-warnings) |
| `debug` | `false` | Log request/response details (credentials are redacted) |
| `logger` | `nil` | Logger instance for debug output (e.g. `Rails.logger`) |
| `broadcast_channel_id` | `nil` | Auto-included on every request when set. Required when using an admin/system token (regular tokens are channel-scoped already). Can be overridden per-call or via `client.with_channel(id) { ... }` |

All methods return parsed JSON as Ruby Hashes with string keys. The returned
object is a `Broadcast::Response` — a Hash subclass that also carries response
metadata (`#warnings`, `#rate_limit`, `#status`, `#idempotent_replay?`).
Anything that worked against a plain Hash still works.

> **Note on module naming:** This gem defines a top-level `Broadcast` module. If your application already has a `Broadcast` class or module (e.g. an ActiveRecord model), you may encounter a namespace collision.

---

## API Warnings

Broadcast accepts a write and then tells you what it ignored. A misspelled
attribute, a parameter that only applies in another mode, a value the server
overrode — none of these fail the request, they come back as a `warnings` array
on the successful response.

This is the difference between "my custom field isn't saving and I can't work
out why" and a one-line answer:

```ruby
result = client.subscribers.create(email: 'jane@example.com', frist_name: 'Jane')

result['id']       # => 42 — the subscriber WAS created
result.warnings?   # => true
result.warnings.each { |w| puts w }
# [unrecognized_parameter] subscriber.frist_name: frist_name is not a recognized
#   subscriber attribute and was ignored.
```

Each warning has `#code`, `#param` (a dot-path, may be nil), and `#message`.
Values you submitted are never echoed back, so warnings are safe to log.

Control what happens via `warnings_mode`:

| Mode | Behaviour |
|------|-----------|
| `:log` (default) | Written to `logger` at WARN level, if a logger is configured |
| `:raise` | Raises `Broadcast::WarningError` |
| `:ignore` | Left on the response for you to inspect |

```ruby
# Recommended in CI or a test suite: turn silent parameter drops into failures
client = Broadcast::Client.new(api_token: '...', host: '...', warnings_mode: :raise)
```

> `:raise` fires **after** the request succeeded. Rescuing `WarningError` does
> not mean the write was rolled back — the subscriber was still created, the
> email was still sent.

Common codes: `unrecognized_parameter`, `parameter_ignored`,
`parameter_overridden`, `double_opt_in_skipped`.

## Rate Limits

Every response carries the current limit state, and 429s are retried
automatically honouring the server's `Retry-After` (capped at `max_retry_delay`).

```ruby
result = client.subscribers.list

result.rate_limit.limit      # => 120
result.rate_limit.remaining  # => 118
result.rate_limit.reset      # => 2026-07-26 12:00:00 UTC

# Back off before you get throttled
sleep 1 if result.rate_limit.remaining < 10
```

If the retries are exhausted you get a `Broadcast::RateLimitError`, which
carries `#retry_after` so you can requeue the job sensibly.

---

## Rails ActionMailer Integration

In a Rails app, the gem auto-registers a `:broadcast` delivery method. Your existing mailers work unchanged.

First, store your API token in Rails credentials:

```bash
bin/rails credentials:edit
```

Add:

```yaml
broadcast:
  api_token: your-token-here
```

Then configure production to use Broadcast:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :broadcast
config.action_mailer.broadcast_settings = {
  api_token: Rails.application.credentials.dig(:broadcast, :api_token),
  host: 'https://mail.example.com'
}
```

All your mailers just work:

```ruby
UserMailer.welcome(user).deliver_later
PasswordsMailer.reset(user).deliver_now
```

The delivery method extracts the HTML body (falling back to text), subject, recipient, and reply-to from the rendered email and sends it via Broadcast's transactional API. Delivery errors raise `Broadcast::DeliveryError`, which lets Active Job (Solid Queue, Sidekiq, etc.) retry automatically.

Development and test environments are unaffected:

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener

# config/environments/test.rb
config.action_mailer.delivery_method = :test
```

### Migrating from Postmark

Replace in your Gemfile:

```diff
- gem 'postmark-rails'
+ gem 'broadcast-ruby'
```

Replace in `config/environments/production.rb`:

```diff
- config.action_mailer.delivery_method = :postmark
- config.action_mailer.postmark_settings = {
-   api_token: Rails.application.credentials.dig(:postmark, :api_token)
- }
+ config.action_mailer.delivery_method = :broadcast
+ config.action_mailer.broadcast_settings = {
+   api_token: Rails.application.credentials.dig(:broadcast, :api_token),
+   host: 'https://mail.example.com'
+ }
```

Your mailer classes, views, and tests stay exactly the same.

### Migrating from SendGrid / Mailgun

Same pattern -- swap the gem and the delivery config. No changes to mailers.

---

## Transactional Email

Send one-off emails triggered by application events. Transactional emails bypass unsubscribe status (for password resets, receipts, order confirmations, etc.).

The sender address is configured at the channel level in your Broadcast instance -- there is no `from` parameter.

**Required permissions:** `transactionals_read`, `transactionals_write`

```ruby
# Send an email
result = client.send_email(
  to: 'user@example.com',
  subject: 'Your password reset link',
  body: '<p>Click <a href="...">here</a> to reset your password.</p>',
  reply_to: 'support@yourapp.com'  # optional
)

result['id']               # => 42
result['recipient_email']  # => 'user@example.com'
result['status_url']       # => '/api/v1/transactionals/42.json'
```

```ruby
# Check delivery status
email = client.get_email(42)
email['sent_at']    # => '2026-03-17T08:00:00Z' (nil if not yet sent)
email['queue_at']   # => '2026-03-17T07:59:58Z'
```

**Parameters for `send_email`:**

| Param | Required | Description |
|-------|----------|-------------|
| `to` | yes | Recipient email address |
| `subject` | yes | Email subject line |
| `body` | yes | Email content (HTML or plain text) |
| `reply_to` | no | Reply-to address |

`send_email` is a thin convenience wrapper. For template-based sends, double opt-in, preheaders, and other advanced options, use `client.transactionals.create`:

```ruby
# Send via a saved Template (resolves subject/body/preheader server-side)
client.transactionals.create(
  to: 'user@example.com',
  template_id: 42,
  reply_to: 'support@yourapp.com',
  include_unsubscribe_link: true
)

# Override individual fields while still using a template
client.transactionals.create(
  to: 'user@example.com',
  template_id: 42,
  subject: 'Custom subject for this send'
)

# Set first/last name on a brand-new subscriber created by this send
client.transactionals.create(
  to: 'new@example.com',
  subject: 'Welcome!',
  body: '<p>Hi {{first_name}}</p>',
  subscriber: { first_name: 'Jane', last_name: 'Doe' }
)

# Get delivery status (alias of client.get_email)
client.transactionals.get_transactional(42)
```

### Idempotent Sends

Pass `idempotency_key:` to make a retry safe. The server stores the response for
24 hours keyed on (token, key) and replays it instead of sending a second email
— so a job that times out after the send but before the ack won't double-mail
your customer.

```ruby
result = client.transactionals.create(
  to: 'user@example.com',
  subject: "Receipt for order ##{order.id}",
  body: receipt_html,
  idempotency_key: "receipt-#{order.id}"
)

result.idempotent_replay?  # => true if this replayed a stored response
```

Use a key derived from the thing you're emailing about (`"receipt-#{order.id}"`),
not a random UUID generated per attempt — a fresh UUID on each retry defeats the
whole mechanism.

Two failure modes worth handling separately:

```ruby
begin
  client.transactionals.create(to: ..., idempotency_key: key)
rescue Broadcast::ConflictError
  # 409 — the original request is still in flight. Retry shortly; do not
  # change the key, or you'll send twice.
  retry_job(wait: 5.seconds)
rescue Broadcast::ValidationError => e
  # 422 with an idempotency key can mean the key was already used with a
  # DIFFERENT payload. Retrying with the same key will never succeed.
  raise
end
```

The fingerprint covers method, full path (including query string), and body.
Changing any of them while reusing a key is what triggers that 422.

### Double Opt-In

Pass `double_opt_in: true` to require email confirmation before delivery. The recipient receives a confirmation email; the actual transactional email is held until they confirm. If the recipient is already a confirmed subscriber, `double_opt_in` is ignored and the email sends normally.

```ruby
# Boolean form: uses the channel's default confirmation template
result = client.transactionals.create(
  to: 'new@example.com',
  subject: 'Welcome!',
  body: '<p>Confirmation email coming first...</p>',
  double_opt_in: true
)
result['confirmation_status']  # => 'pending'
result['confirmation_url']     # => 'https://...'

# Hash form: customize the confirmation flow
client.transactionals.create(
  to: 'new@example.com',
  subject: 'Welcome!',
  body: '<p>...</p>',
  double_opt_in: {
    reply_to: 'support@yourapp.com',
    confirmation_template_id: 7,
    include_unsubscribe_link: true
  }
)

# Equivalent shortcut for confirmation_template_id at the top level
client.transactionals.create(
  to: 'new@example.com',
  subject: 'Welcome!',
  body: '<p>...</p>',
  double_opt_in: true,
  confirmation_template_id: 7
)
```

A transactional email server must be configured for the channel and a confirmation template (or default) must exist, otherwise the request returns 422.

---

## Subscribers

Manage your contact list. Subscribers can have tags and custom data fields for segmentation and personalization.

**Required permissions:** `subscribers_read`, `subscribers_write`

```ruby
# List subscribers (paginated, 250 per page)
result = client.subscribers.list(page: 1)
result['subscribers']            # => [{'email' => '...', 'tags' => [...], ...}, ...]
result['pagination']['total']    # => 1500
result['pagination']['current']  # => 1

# Filter by status, tags, dates, or custom data -- all combinable
client.subscribers.list(is_active: true)
client.subscribers.list(source: 'opt_in_form')
client.subscribers.list(tags: ['newsletter', 'premium'])   # AND -- must have all
client.subscribers.list(email: 'example.com')              # partial match, not exact
client.subscribers.list(confirmation_status: 'unconfirmed')
client.subscribers.list(created_after: '2026-01-01T00:00:00Z',
                        created_before: '2026-02-01T00:00:00Z')
client.subscribers.list(custom_data: { plan: 'pro' })       # JSONB containment
```

> An unparseable `created_after` / `created_before` is **ignored** by the server
> rather than rejected — you get every subscriber back, plus a
> `parameter_ignored` warning. Check `result.warnings` (or run with
> `warnings_mode: :raise`) if a filtered count looks too high.

```ruby
# Find by email
subscriber = client.subscribers.find(email: 'jane@example.com')
subscriber['email']        # => 'jane@example.com'
subscriber['first_name']   # => 'Jane'
subscriber['tags']         # => ['newsletter', 'premium']
subscriber['custom_data']  # => {'plan' => 'pro'}
subscriber['is_active']    # => true
```

```ruby
# Create a subscriber
# Returns the created subscriber as a Hash
client.subscribers.create(
  email: 'jane@example.com',
  first_name: 'Jane',
  last_name: 'Doe',
  tags: ['newsletter', 'free-tier'],
  custom_data: { plan: 'free', signup_source: 'landing_page' }
)

# Update a subscriber (identified by email)
# Returns the updated subscriber as a Hash
client.subscribers.update('jane@example.com',
  first_name: 'Janet',
  tags: ['newsletter', 'premium'],  # replaces all tags
  custom_data: { plan: 'pro' }
)

# Change a subscriber's email address
client.subscribers.update('old@example.com', email: 'new@example.com')
```

```ruby
# Add tags without replacing existing ones
client.subscribers.add_tags('jane@example.com', ['vip', 'early-adopter'])

# Remove specific tags
client.subscribers.remove_tags('jane@example.com', ['free-tier'])
```

```ruby
# Deactivate (stop all email delivery, keep record)
client.subscribers.deactivate('jane@example.com')

# Activate (resume email delivery)
client.subscribers.activate('jane@example.com')

# Unsubscribe (marks as unsubscribed AND deactivates)
client.subscribers.unsubscribe('jane@example.com')

# Resubscribe (clears unsubscribed status AND activates)
client.subscribers.resubscribe('jane@example.com')

# Redact -- GDPR "right to be forgotten" (irreversible)
# Removes PII but preserves aggregate campaign statistics
client.subscribers.redact('jane@example.com')
```

### Double Opt-In

Pass `double_opt_in: true` (or a hash) to create the subscriber in unconfirmed state and queue a confirmation email. If the subscriber already exists and is confirmed, `double_opt_in` is ignored and the existing record is returned.

```ruby
# Boolean form (uses the channel's default confirmation template)
result = client.subscribers.create(
  email: 'new@example.com',
  first_name: 'Jane',
  double_opt_in: true
)
result['confirmation_status']  # => 'pending'
result['confirmation_url']     # => '...'

# Hash form -- customize reply-to, template, and unsubscribe link
client.subscribers.create(
  email: 'new@example.com',
  double_opt_in: {
    reply_to: 'support@yourapp.com',
    confirmation_template_id: 7,
    include_unsubscribe_link: true
  }
)

# `confirmation_template_id` is also accepted at the top level
client.subscribers.create(
  email: 'new@example.com',
  double_opt_in: true,
  confirmation_template_id: 7
)
```

`double_opt_in` and `confirmation_template_id` are top-level options -- they do **not** go inside the `subscriber:` envelope on the wire (the gem extracts them automatically).

The channel must have an active transactional email server and a confirmation template (default or `confirmation_template_id`), otherwise the request returns 422.

---

## Sequences

Automated drip campaigns. Add subscribers to a sequence and they flow through the steps automatically.

**Required permissions:** `sequences_read`, `sequences_write` (also `subscribers_read`, `subscribers_write` for enrollment)

```ruby
# List all sequences
result = client.sequences.list
result # => [{'id' => 1, 'label' => 'Onboarding', 'active' => true, 'subscribers_count' => 42, ...}, ...]

# Get a single sequence
sequence = client.sequences.get_sequence(1)

# Get with steps included
sequence = client.sequences.get_sequence(1, include_steps: true)
sequence['steps']  # => [{'id' => 10, 'action' => 'delay', ...}, ...]

# Create
result = client.sequences.create(label: 'Onboarding', active: false)
result['id']  # => 5

# Create with auto-enrollment by tag
# Subscribers are auto-added when this tag is applied to them
client.sequences.create(
  label: 'Free Trial Nurture',
  init_tag: 'free-trial',
  active: true
)

# Create with auto-enrollment by segment
# Matching subscribers are synced every 15 minutes
client.sequences.create(
  label: 'Re-engagement',
  init_segment_id: 5,
  active: true
)

# Update
client.sequences.update(1, label: 'Updated Onboarding', active: true)

# Delete (and all its steps)
client.sequences.delete(1)
```

### Subscriber Enrollment

```ruby
# Add subscriber to sequence (creates subscriber if new)
client.sequences.add_subscriber(1, email: 'jane@example.com', first_name: 'Jane')

# Remove subscriber from sequence
client.sequences.remove_subscriber(1, email: 'jane@example.com')

# List subscribers in a sequence
# Returns subscriber_sequences objects with enrollment status
result = client.sequences.list_subscribers(1, page: 1)
result['subscriber_sequences']
# => [{'id' => 1, 'status' => 'active', 'started_at' => '...', 'next_trigger_at' => '...',
#      'subscriber' => {'id' => '123', 'email' => 'jane@example.com'}}, ...]
```

### Steps

```ruby
# List steps in a sequence
client.sequences.list_steps(sequence_id)

# Get a single step
step = client.sequences.get_step(sequence_id, step_id)

# Create steps -- each step needs an action, label, and parent_id
# The parent_id links steps into a tree (entry point is the sequence's root step)

# Delay step (seconds)
client.sequences.create_step(sequence_id,
  action: 'delay', label: 'Wait 1 day',
  parent_id: entry_point_id, delay: 86400
)

# Email step
client.sequences.create_step(sequence_id,
  action: 'send_email', label: 'Welcome email',
  parent_id: delay_step_id,
  subject: 'Welcome!', body: '<h1>Welcome!</h1>'
)

# Condition step (branches based on engagement)
client.sequences.create_step(sequence_id,
  action: 'condition', label: 'Opened welcome email?',
  parent_id: email_step_id,
  condition_setting: 'previous_email_opened'
)

# Tag step
client.sequences.create_step(sequence_id,
  action: 'add_tag_to_subscriber', label: 'Tag as engaged',
  parent_id: condition_yes_id, taggify_list: 'engaged,onboarded'
)

# Update a step
client.sequences.update_step(sequence_id, step_id, label: 'Updated')

# Move a step under a different parent
client.sequences.move_step(sequence_id, step_id, under_id: new_parent_id)

# Delete a step
client.sequences.delete_step(sequence_id, step_id)
```

**Step actions:** `send_email`, `delay`, `delay_until_time`, `condition`, `move_to_sequence`, `add_tag_to_subscriber`, `remove_tag_from_subscriber`, `deactivate_subscriber`, `make_http_request`

**Condition settings:** `any_email_opened`, `previous_email_opened`, `any_email_clicked`, `previous_email_clicked`

---

## Broadcasts

One-time email campaigns sent to your subscriber list or targeted segments.

**Required permissions:** `broadcasts_read`, `broadcasts_write`

```ruby
# List broadcasts
result = client.broadcasts.list(limit: 10, offset: 0)
# => [{'id' => 1, 'name' => '...', 'subject' => '...', 'status' => 'draft', ...}, ...]

# Get a broadcast
broadcast = client.broadcasts.get_broadcast(1)
broadcast['status']  # => 'draft'

# Create a broadcast (starts as draft)
result = client.broadcasts.create(
  subject: 'March Newsletter',
  body: '<h1>What is new</h1><p>Updates...</p>',
  name: 'march-2026-newsletter',
  preheader: 'Product updates and tips',
  reply_to: 'hello@yourapp.com',
  track_opens: true,
  track_clicks: true,
  segment_ids: [1, 3],
  taggify_list: 'newsletter,march-2026'
)
result['id']  # => 5

# Update (draft or scheduled only)
client.broadcasts.update(1, subject: 'Updated Subject')

# Send immediately (draft or failed only)
result = client.broadcasts.send_broadcast(1)
result['status']  # => 'queueing'

# Schedule for later
result = client.broadcasts.schedule(1,
  scheduled_send_at: '2026-03-20T09:00:00Z',
  scheduled_timezone: 'America/Toronto'
)
result['status']  # => 'future_scheduled'

# Cancel a scheduled broadcast (returns to draft)
client.broadcasts.cancel_schedule(1)

# Delete (draft or scheduled only)
client.broadcasts.delete(1)
```

### Statistics

```ruby
# Delivery and engagement stats
stats = client.broadcasts.statistics(1)
stats['delivery']['sent']                # => 1500
stats['engagement']['opens']['count']    # => 723
stats['engagement']['clicks']['count']   # => 184
stats['issues']['bounces']['count']      # => 12
stats['issues']['unsubscribes']['count'] # => 3

# Timeline stats (for charts)
client.broadcasts.statistics_timeline(1, timeframe: '24h', metrics: 'opens,clicks')
# timeframes: 60m, 120m, 3h, 6h, 12h, 18h, 24h, 48h, 72h, 7d, 14d

# Per-link click stats
client.broadcasts.statistics_links(1, sort: 'clicks', order: 'desc')
```

**Broadcast statuses:** `draft`, `future_scheduled`, `scheduled`, `queueing`, `sending`, `sent`, `failed`, `partial_failure`, `aborted`, `paused`

---

## Segments

Define subscriber groups using rules for targeted broadcasts and sequence enrollment.

**Required permissions:** `segments_read`, `segments_write`

```ruby
# List segments
result = client.segments.list
result['segments']  # => [{'id' => 1, 'name' => 'Active Users', ...}, ...]

# Get segment with matching subscribers (paginated)
result = client.segments.get_segment(1, page: 1)
result['segment']                # => {'id' => 1, 'name' => 'Active Users', ...}
result['subscribers']            # => [{'email' => '...', ...}, ...]
result['pagination']['total']    # => 150

# Create a segment with rules
# Groups are OR'd together; rules within a group are combined by match_type (all = AND, any = OR)
result = client.segments.create(
  name: 'Active Gmail Users',
  description: 'Gmail users who opened an email in the last 30 days',
  segment_groups_attributes: [
    {
      match_type: 'all',
      segment_rules_attributes: [
        { field: 'email', operator: 'contains', value: 'gmail.com',
          rule_type: 'text', value_type: 'string' },
        { field: 'last_email_opened_at', operator: 'within_last_days', value: '30',
          rule_type: 'date', value_type: 'string' }
      ]
    }
  ]
)
result['id']  # => 5

# Update
client.segments.update(1, name: 'Updated Name')

# Delete
client.segments.delete(1)
```

**Rule fields:** `email`, `first_name`, `last_name`, `tags`, `is_active`, `created_at`, `last_email_sent_at`, `last_email_opened_at`, `last_email_clicked_at`, `total_emails_sent`, `total_emails_opened`, `total_emails_clicked`, `has_opened_any_email`, `has_clicked_any_email`

**Operators by type:**
- **Text:** `equals`, `not_equals`, `contains`, `not_contains`, `starts_with`, `ends_with`, `is_empty`, `is_not_empty`
- **Number:** `equals`, `not_equals`, `greater_than`, `less_than`, `greater_than_or_equal`, `less_than_or_equal`
- **Date:** `equals`, `before`, `after`, `within_last_days`, `not_within_last_days`, `never`, `is_empty`, `is_not_empty`
- **Boolean:** `is_true`, `is_false`

---

## Templates

Reusable email templates with [Liquid](https://shopify.github.io/liquid/) variable support for personalization (e.g. `{{first_name}}`, `{{email}}`).

**Required permissions:** `templates_read`, `templates_write`

```ruby
# List all templates
result = client.templates.list
result['data']  # => [{'id' => 1, 'label' => 'Welcome', 'subject' => '...', ...}, ...]

# Get a template
template = client.templates.get_template(1)
template['label']    # => 'Welcome'
template['subject']  # => 'Hello {{first_name}}'
template['body']     # => '<h1>Welcome!</h1>'

# Create a template
# Returns {'id' => number}
client.templates.create(
  label: 'Monthly Newsletter',
  subject: 'Your {{month}} update',
  body: '<h1>Hello {{first_name}}</h1><p>Here is what happened...</p>',
  preheader: 'Your monthly digest',
  html_body: true
)

# Update
client.templates.update(1, subject: 'Updated subject')

# Delete
client.templates.delete(1)
```

---

## Opt-In Forms

Embeddable subscription forms with theming, A/B variants, and analytics.

**Required permissions:** `opt_in_forms_read`, `opt_in_forms_write`

```ruby
# List forms (paginated, up to 250 per page; only main forms -- variants are excluded)
result = client.opt_in_forms.list
result['opt_in_forms']            # => [{'id' => 1, 'label' => 'Newsletter', ...}, ...]
result['pagination']['current']   # => 1
result['pagination']['total']     # => 12

# Filter
client.opt_in_forms.list(filter: 'newsletter', widget_type: 'inline', enabled: 'true')

# Get a single form (full payload incl. blocks and settings)
form = client.opt_in_forms.get_opt_in_form(1)

# Create a form
result = client.opt_in_forms.create(
  label: 'Newsletter Signup',
  form_type: 'inline',
  widget_type: 'inline',
  enabled: true,
  theme_settings: {
    colors: { primary: '#3b82f6', background: '#ffffff', text: '#111827', border: '#d1d5db' }
  },
  automation_settings: {
    tag_list: 'newsletter',
    send_welcome_email: true,
    double_opt_in: true,
    sequence_ids: [3]
  }
)

# Update (deeply nested settings hashes pass through verbatim)
client.opt_in_forms.update(1, enabled: false)

# Delete
client.opt_in_forms.delete(1)
```

### Analytics

```ruby
# Last 30 days by default
client.opt_in_forms.analytics(1)

# Custom date range -- accepts Date, Time, or ISO-8601 strings
client.opt_in_forms.analytics(1,
  start_date: Date.new(2026, 1, 1),
  end_date: Date.new(2026, 1, 31)
)
# Returns: { totals: { views, unique_views, submissions, conversion_rate },
#            daily: [...], variants: [...] }
```

### A/B Variants

```ruby
# Create a variant of a form (defaults to "Variant N" / weight 50)
client.opt_in_forms.create_variant(1, name: 'B', weight: 50)

# Duplicate a form into a new top-level form (counts toward your plan limit)
client.opt_in_forms.duplicate(1, label: 'Newsletter Signup (Copy)')
```

> **Note:** `index`/`show` and `create`/`update` return slightly different JSON shapes (the index/show responses go through JBuilder views; create/update use a richer inline serializer with analytics counts and embed URL). Don't depend on field-level parity between these paths.

---

## Email Servers

Configure outbound email providers for a channel (SMTP, AWS SES, Postmark, Inboxroad, SMTP.com, etc.).

**Required permissions:** `email_servers_read`, `email_servers_write`

```ruby
# List email servers
result = client.email_servers.list
result['data']   # => [{'id' => 1, 'label' => 'Primary SES', 'vendor' => 'aws_ses', ...}, ...]
result['total']  # => 3

# Pagination
client.email_servers.list(limit: 10, offset: 0)

# Get a single email server
es = client.email_servers.get_email_server(1)

# Create -- example: AWS SES
client.email_servers.create(
  label: 'Primary SES',
  vendor: 'aws_ses',
  delivery_method: 'aws_ses',
  active: true,
  aws_region: 'us-east-1',
  aws_access_key_id: 'AKIA...',
  aws_secret_access_key: 'secret...',
  use_for_broadcasts: true,
  use_for_sequences: true,
  use_for_transactionals: true
)

# Create -- example: SMTP
client.email_servers.create(
  label: 'Backup SMTP',
  vendor: 'smtp',
  delivery_method: 'smtp',
  smtp_address: 'smtp.example.com',
  smtp_port: 587,
  smtp_username: 'user',
  smtp_password: 'pass',
  smtp_authentication: 'plain',
  smtp_enable_starttls_auto: true,
  emails_per_hour: 10000
)

# Update -- pass only the fields you want to change
client.email_servers.update(1, label: 'Primary SES (updated)', emails_per_hour: 50000)

# Test the connection (toggles `active` based on result)
result = client.email_servers.test_connection(1)
result['success']  # => true / false
result['message']  # => 'Connection successful' / 'Connection failed'

# Delete
client.email_servers.delete(1)
```

### Credential Redaction

API responses redact credential fields with bullet characters (e.g. `smtp_password: "abcd••••••wxyz"`). **Never round-trip a fetched response back into `update`** -- the gem detects redacted-shape values on known credential fields (`smtp_password`, `aws_*`, `postmark_api_token`, `inboxroad_api_token`, `smtp_com_api_key`) and silently strips them from the payload (with a warning) so they don't overwrite the real value:

```ruby
# Safe -- only the fields you actually want to change
client.email_servers.update(1, label: 'New label', emails_per_hour: 25000)

# This would corrupt credentials WITHOUT the gem's scrubber:
es = client.email_servers.get_email_server(1)
client.email_servers.update(1, **es)  # bullets get scrubbed, label still updates

# To rotate a credential, pass the real new value
client.email_servers.update(1, smtp_password: 'new-real-secret')
```

### Cross-Channel Copy (admin tokens only)

`copy_to_channel` clones an email server (with all settings and headers) into another channel. **Requires an admin/system token** with `email_servers_write` permission. Regular per-channel tokens get `Broadcast::AuthorizationError`. In SaaS mode, the target channel must be in the admin token creator's account.

```ruby
admin_client = Broadcast::Client.new(
  api_token: ENV['BROADCAST_ADMIN_TOKEN'],
  broadcast_channel_id: 1   # the source server's channel
)

admin_client.email_servers.copy_to_channel(99, target_channel_id: 7)
```

---

## Channel Scoping (Admin/System Tokens)

Regular API tokens are scoped to a single broadcast channel automatically. Admin/system tokens are not -- they require `broadcast_channel_id` on every request to indicate which channel they're acting on.

The gem auto-includes `broadcast_channel_id` from your `Configuration` on every request:

```ruby
# Set globally
client = Broadcast::Client.new(
  api_token: ENV['BROADCAST_ADMIN_TOKEN'],
  broadcast_channel_id: 1
)
client.email_servers.list  # broadcast_channel_id=1 is appended automatically
```

For multi-channel scripts, use `with_channel` to scope a block of calls to a specific channel:

```ruby
client = Broadcast::Client.new(api_token: ENV['BROADCAST_ADMIN_TOKEN'])

client.with_channel(1) do
  client.email_servers.list
  client.opt_in_forms.list
end

client.with_channel(2) do
  client.subscribers.list
end
```

`with_channel` overrides the config-level value inside the block. Per-call `broadcast_channel_id:` always wins over both. The override is thread-local, so it's safe to share a `Client` instance across threads.

---

## Webhook Endpoints

Receive real-time notifications when events occur (email delivered, subscriber created, sequence completed, etc.).

**Required permissions:** `webhook_endpoints_read`, `webhook_endpoints_write`

```ruby
# List endpoints
result = client.webhook_endpoints.list
result['data']  # => [{'id' => 1, 'url' => '...', 'active' => true, ...}, ...]

# Get an endpoint
endpoint = client.webhook_endpoints.get_endpoint(1)

# Create an endpoint
result = client.webhook_endpoints.create(
  url: 'https://yourapp.com/webhooks/broadcast',
  event_types: [
    'email.sent', 'email.delivered', 'email.opened', 'email.clicked',
    'subscriber.created', 'subscriber.unsubscribed',
    'sequence.subscriber_added', 'sequence.subscriber_completed'
  ],
  retries_to_attempt: 6
)
# IMPORTANT: Save the secret from the response -- it is only shown once
secret = result['secret']

# Every valid event type is available as a constant. An unknown event type is
# dropped server-side rather than rejected, so subscribe from these.
Broadcast::Webhook::EVENT_TYPES        # all 32
Broadcast::Webhook::EMAIL_EVENTS       # email.sent, email.delivered, ...
Broadcast::Webhook::SUBSCRIBER_EVENTS  # subscriber.created, ...
Broadcast::Webhook::BROADCAST_EVENTS   # broadcast.sending, broadcast.sent, ...
Broadcast::Webhook::SEQUENCE_EVENTS    # sequence.subscriber_added, ...
Broadcast::Webhook::SYSTEM_EVENTS      # message.attempt.exhausted, test.webhook

client.webhook_endpoints.create(
  url: 'https://yourapp.com/webhooks/broadcast',
  event_types: Broadcast::Webhook::EMAIL_EVENTS
)

# Update (url and secret cannot be changed -- create a new endpoint instead)
client.webhook_endpoints.update(1, active: false)
client.webhook_endpoints.update(1, event_types: ['email.delivered', 'email.opened'])

# Delete
client.webhook_endpoints.delete(1)

# Send a test webhook
client.webhook_endpoints.test(1, event_type: 'email.delivered')

# View delivery history
result = client.webhook_endpoints.deliveries(1, limit: 10)
result['data']  # => [{'id' => 1, 'event_type' => 'email.sent', 'response_status' => 200, ...}, ...]
```

**Event types:**

| Category | Events |
|----------|--------|
| Email | `email.sent`, `email.delivered`, `email.delivery_delayed`, `email.opened`, `email.clicked`, `email.bounced`, `email.complained`, `email.failed` |
| Subscriber | `subscriber.created`, `subscriber.updated`, `subscriber.deleted`, `subscriber.subscribed`, `subscriber.unsubscribed`, `subscriber.bounced`, `subscriber.complained` |
| Broadcast | `broadcast.scheduled`, `broadcast.queueing`, `broadcast.sending`, `broadcast.sent`, `broadcast.failed`, `broadcast.partial_failure`, `broadcast.aborted`, `broadcast.paused` |
| Sequence | `sequence.subscriber_added`, `sequence.subscriber_completed`, `sequence.subscriber_moved`, `sequence.subscriber_removed`, `sequence.subscriber_paused`, `sequence.subscriber_resumed`, `sequence.subscriber_error` |
| System | `message.attempt.exhausted`, `test.webhook` |

### Webhook Signature Verification

All incoming webhooks are signed with HMAC-SHA256. Here's a complete Rails controller:

```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.raw_post
    signature = request.headers['broadcast-webhook-signature']
    timestamp = request.headers['broadcast-webhook-timestamp']

    unless Broadcast::Webhook.verify(payload, signature, timestamp,
                                     secret: ENV['BROADCAST_WEBHOOK_SECRET'])
      head :unauthorized
      return
    end

    event = JSON.parse(payload)

    case event['type']
    when 'email.delivered'
      # handle delivery
    when 'subscriber.unsubscribed'
      # handle unsubscribe
    end

    head :ok
  end
end
```

The signature is computed as `HMAC-SHA256(timestamp + "." + payload, secret)`. Timestamps older than 5 minutes are rejected to prevent replay attacks.

---

## Autopilot

AI-generated newsletters. An autopilot reads your configured sources on a
schedule, drafts copy in the tone you describe, and produces broadcast drafts
for review. Requires `autopilot_read` / `autopilot_write`.

```ruby
client.autopilots.list
client.autopilots.get_autopilot(id)

autopilot = client.autopilots.create(
  name: 'Weekly Roundup',
  openrouter_api_key: ENV['OPENROUTER_API_KEY'],
  ai_model: 'openai/gpt-4o',
  schedule_frequency: 'weekly',
  schedule_day_of_week: 1,
  schedule_time: '09:00',
  schedule_timezone: 'America/New_York',
  copies_to_generate: 3,
  tone_description: 'Direct and technical. No hype.',
  content_instructions: 'Lead with the most consequential change.',
  segment_ids: [ 12 ]
)

client.autopilots.update(autopilot['id'], copies_to_generate: 5)
client.autopilots.delete(autopilot['id'])
```

### Lifecycle

```ruby
client.autopilots.activate(id)     # start running on schedule
client.autopilots.pause(id)        # keep config, stop generating
client.autopilots.deactivate(id)
```

`activate` requires **at least one active source, an API key, and a model**. If
any is missing it raises `Broadcast::ValidationError` naming the prerequisites:

```ruby
begin
  client.autopilots.activate(id)
rescue Broadcast::ValidationError => e
  # All missing prerequisites, comma-joined:
  e.message # => "At least one active source is required, AI model is required"
end
```

Sources and tone samples have **no API endpoints yet** — they are configured in
the web UI. Since `activate` needs an active source, a brand-new autopilot
created over the API cannot be activated until a source is added there.

### Runs

`trigger_run` queues generation immediately and returns `202` — the work is
asynchronous, so poll rather than expecting finished copy back:

```ruby
run = client.autopilots.trigger_run(id)
run['status']   # => "pending"

client.autopilots.runs(id, limit: 10)   # most recent first
```

### API key handling

`openrouter_api_key` is write-only. It is encrypted at rest and never returned —
reads expose only `api_key_configured`. The API renders a configured key
bullet-masked, and writing that mask back would replace a working credential
with bullets, so `update` strips it and warns:

```ruby
current = client.autopilots.get_autopilot(id)
current['api_key_configured']   # => true
current['openrouter_api_key']   # => nil — never returned

# Safe: the masked value is dropped, the stored key survives
client.autopilots.update(id, openrouter_api_key: '••••••••', ai_model: 'openai/gpt-4o')
```

Pass the real key to rotate it, or omit the field entirely. This is the same
guard as [Email Servers](#credential-redaction).

---

## Discovery

Ask the instance what this token can do and whether the channel is ready to
send. Useful as a deploy-time smoke check, and as the entry point for agents
and CLIs.

```ruby
# Who am I? Token type, permissions, resolved channel.
me = client.whoami
me['token']['type']          # => 'channel_scoped' or 'admin_cross_channel'
me['token']['permissions']   # => { 'subscribers' => ['read', 'write'], ... }
me['channel']['name']        # => 'Main'

# Is this channel actually able to send?
status = client.status
status['subscribers']['active']     # => 1042
status['readiness']['broadcasts']   # => true
status['readiness']['sequences']    # => false — no email server configured

# Full capability manifest: platform version, endpoint list, rate limit, tips.
client.prime

# Plain-text agent skill manifest (Markdown + YAML front matter).
# Returns a String, not a Hash.
puts client.skill
```

A useful preflight before a send job:

```ruby
raise 'channel not ready to send' unless client.status.dig('readiness', 'broadcasts')
```

---

## Export & Migration (admin tokens only)

Read-only endpoints under `/api/migration/v1` for backups and moving a channel
between instances. Two constraints differ from the rest of the API:

- **Admin tokens only.** Channel-scoped tokens are rejected.
- **`broadcast_channel_id` is required on every call.** Set it once on the
  client and the gem attaches it for you.

```ruby
client = Broadcast::Client.new(
  api_token: ENV['BROADCAST_ADMIN_TOKEN'],
  host: 'https://mail.example.com',
  broadcast_channel_id: 1
)

# Size the export first
manifest = client.migration.manifest
manifest['counts']            # => { 'subscribers' => 5000, 'templates' => 12, ... }
manifest['export_format_version']

# Time-bounded counts (broadcasts, receipts, histories) default to 90 days
client.migration.manifest(days_history: 365)
```

Each collection is a paginated list returning `data` and `pagination`:

```ruby
page = client.migration.subscribers(limit: 250, offset: 0)
page['data']
page['pagination']  # => { 'total' => 5000, 'limit' => 250, 'offset' => 0, 'has_more' => true }
```

`each_record` handles the paging for you, advancing by the page size the server
actually granted rather than the one you asked for:

```ruby
CSV.open('subscribers.csv', 'w') do |csv|
  client.migration.each_record(:subscribers) do |subscriber|
    csv << [subscriber['email'], subscriber['first_name'], subscriber['created_at']]
  end
end

# Without a block you get an Enumerator
client.migration.each_record(:tags).map { |tag| tag['name'] }
```

Available collections:

```
channels  subscribers  templates  segments  sequences  email_servers
opt_in_forms  broadcasts  outbound_receipts  webhook_endpoints  tokens
suppressions  tags  users  link_redirects  link_clicks
subscriber_histories  file_assets
```

File assets are downloaded separately and return raw bytes:

```ruby
bytes = client.migration.download_file_asset(7)
File.binwrite('logo.png', bytes)
```

---

## Error Handling

All API errors inherit from `Broadcast::Error`. Put specific errors before general ones:

```ruby
begin
  client.send_email(to: 'user@example.com', subject: 'Hi', body: 'Hello')
rescue Broadcast::AuthenticationError  # 401 -- invalid or expired API token
rescue Broadcast::AuthorizationError   # 403 -- token lacks the required permission, or admin-only endpoint
rescue Broadcast::NotFoundError        # 404 -- resource does not exist
rescue Broadcast::ConflictError        # 409 -- Idempotency-Key request still in flight
rescue Broadcast::ValidationError      # 422 -- missing or invalid parameters
rescue Broadcast::RateLimitError       # 429 -- rate limited; carries #retry_after
rescue Broadcast::TimeoutError         # connection or read timeout
rescue Broadcast::APIError             # 5xx or unexpected status codes
rescue Broadcast::WarningError         # warnings_mode: :raise -- request SUCCEEDED
rescue Broadcast::ConfigurationError   # missing api_token or host
rescue Broadcast::DeliveryError        # ActionMailer wrapper (wraps any of the above)
end
```

Server errors (5xx), timeouts, and rate limits (429) are retried automatically —
429s honour the server's `Retry-After`, bounded by `max_retry_delay`. Other
client errors (401, 403, 404, 409, 422) are raised immediately.

`DeliveryError` is only raised from the ActionMailer delivery method and wraps
the underlying API error. `WarningError` is deliberately not wrapped: the email
was sent, so reporting it as a delivery failure would be wrong.

---

## API Token Permissions

Each token can be scoped to specific resources. The ActionMailer delivery method only needs transactional permissions. Use the minimum permissions your integration requires.

| Resource | Read permission | Write permission |
|----------|----------------|------------------|
| Transactional Emails | `transactionals_read` -- get delivery status | `transactionals_write` -- send emails |
| Subscribers | `subscribers_read` -- list, find | `subscribers_write` -- create, update, tag, deactivate, unsubscribe, redact |
| Sequences | `sequences_read` -- list, get, list steps | `sequences_write` -- create, update, delete, manage steps, enroll subscribers |
| Broadcasts | `broadcasts_read` -- list, get, statistics | `broadcasts_write` -- create, update, delete, send, schedule |
| Segments | `segments_read` -- list, get | `segments_write` -- create, update, delete |
| Templates | `templates_read` -- list, get | `templates_write` -- create, update, delete |
| Opt-In Forms | `opt_in_forms_read` -- list, get, analytics | `opt_in_forms_write` -- create, update, delete, create_variant, duplicate |
| Email Servers | `email_servers_read` -- list, get | `email_servers_write` -- create, update, delete, test_connection, copy_to_channel (admin) |
| Webhook Endpoints | `webhook_endpoints_read` -- list, get, deliveries | `webhook_endpoints_write` -- create, update, delete, test |
| Autopilot | `autopilot_read` -- list, get, runs | `autopilot_write` -- create, update, delete, activate, pause, deactivate, trigger_run |

---

## Troubleshooting

### `Broadcast::AuthenticationError` (401)

- **Wrong token:** Double-check you copied the full token from your Broadcast dashboard.
- **Wrong host:** Make sure `host` points at your own Broadcast instance. There is no default.
- **Missing permissions:** Your token may not have the required permissions for the resource you're accessing. Check the [permissions table](#api-token-permissions).

### `Broadcast::AuthorizationError` (403)

- **Missing permission:** Your token doesn't have the read or write permission for the resource (e.g. calling `client.opt_in_forms.create` with a token that only has `opt_in_forms_read`).
- **Admin-only endpoint:** `email_servers.copy_to_channel` requires an admin/system token. Regular per-channel tokens cannot perform cross-channel operations.
- **Missing channel scope on admin token:** Admin tokens require `broadcast_channel_id` on every request. Set it on `Broadcast::Client.new(broadcast_channel_id: …)` or wrap calls with `client.with_channel(id) { … }`.

### `Broadcast::ValidationError` (422)

- **Missing required fields:** Check the parameters table for the method you're calling.
- **Duplicate subscriber:** Creating a subscriber with an email that already exists returns 422. Use `find` first or handle the error.
- **Duplicate template label:** Template labels must be unique within a channel.

### `Broadcast::NotFoundError` (404)

- **Wrong ID:** The resource ID doesn't exist or belongs to a different channel.
- **Subscriber not found:** `subscribers.find(email: '...')` raises 404 if no subscriber matches.

### `Broadcast::TimeoutError`

- **Slow network:** Increase `timeout` and `open_timeout` in client options.
- **Large response:** Template list responses can be large if templates contain full HTML bodies.

### `Broadcast::RateLimitError` (429)

- **Rate limit:** Broadcast allows 120 requests per minute per token. The gem does not auto-retry on 429 -- back off and retry in your application code.

### ActionMailer emails not sending

- **Check delivery method:** Ensure `config.action_mailer.delivery_method = :broadcast` is set in the right environment file (not development or test).
- **Check credentials:** Run `bin/rails credentials:show` and verify `broadcast.api_token` is set.
- **Check logs:** Set `debug: true` in `broadcast_settings` to see request/response details.

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
