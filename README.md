# broadcast-ruby

Ruby client for the [Broadcast](https://sendbroadcast.com) email platform.

Works with [sendbroadcast.com](https://sendbroadcast.com) or any self-hosted Broadcast instance.

## Installation

Add to your Gemfile:

```ruby
gem 'broadcast-ruby', '~> 0.1', require: 'broadcast'
```

The `require: 'broadcast'` is needed because the gem name differs from the require path.

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
  host: 'https://sendbroadcast.com'  # or your self-hosted URL
)

client.send_email(
  to: 'jane@example.com',
  subject: 'Welcome!',
  body: '<h1>Hello Jane</h1><p>Welcome aboard.</p>'
)
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `api_token` | *required* | Your Broadcast API token |
| `host` | `https://sendbroadcast.com` | Broadcast instance URL |
| `timeout` | `30` | Read timeout (seconds) |
| `open_timeout` | `10` | Connection timeout (seconds) |
| `retry_attempts` | `3` | Max total attempts (1 initial + 2 retries). Server errors (5xx) and timeouts are retried; client errors (4xx) are not |
| `retry_delay` | `1` | Base delay between retries in seconds (multiplied by attempt number) |
| `debug` | `false` | Log request/response details |
| `logger` | `nil` | Logger instance for debug output (e.g. `Rails.logger`) |

All methods return parsed JSON as Ruby Hashes with string keys.

> **Note on module naming:** This gem defines a top-level `Broadcast` module. If your application already has a `Broadcast` class or module (e.g. an ActiveRecord model), you may encounter a namespace collision.

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
  host: 'https://sendbroadcast.com'
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
+   host: 'https://sendbroadcast.com'
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

# Filter by status, tags, dates, or custom data
client.subscribers.list(is_active: true)
client.subscribers.list(tags: ['newsletter', 'premium'])
client.subscribers.list(created_after: '2026-01-01T00:00:00Z')
client.subscribers.list(custom_data: { plan: 'pro' })
```

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

## Error Handling

All API errors inherit from `Broadcast::Error`. Put specific errors before general ones:

```ruby
begin
  client.send_email(to: 'user@example.com', subject: 'Hi', body: 'Hello')
rescue Broadcast::AuthenticationError  # 401 -- invalid or expired API token
rescue Broadcast::NotFoundError        # 404 -- resource does not exist
rescue Broadcast::ValidationError      # 422 -- missing or invalid parameters
rescue Broadcast::RateLimitError       # 429 -- exceeded 120 requests/minute
rescue Broadcast::TimeoutError         # connection or read timeout
rescue Broadcast::APIError             # 5xx or unexpected status codes
rescue Broadcast::DeliveryError        # ActionMailer wrapper (wraps any of the above)
end
```

Server errors (5xx) and timeouts are automatically retried with linear backoff. Client errors (401, 404, 422, 429) are raised immediately. `DeliveryError` is only raised from the ActionMailer delivery method -- it wraps the underlying API error.

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
| Webhook Endpoints | `webhook_endpoints_read` -- list, get, deliveries | `webhook_endpoints_write` -- create, update, delete, test |

---

## Troubleshooting

### `Broadcast::AuthenticationError` (401)

- **Wrong token:** Double-check you copied the full token from your Broadcast dashboard.
- **Wrong host:** If you're self-hosting, make sure `host` points to your Broadcast instance, not `sendbroadcast.com`.
- **Missing permissions:** Your token may not have the required permissions for the resource you're accessing. Check the [permissions table](#api-token-permissions).

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
