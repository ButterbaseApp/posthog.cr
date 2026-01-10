# Getting Started with PostHog Crystal SDK

This guide will help you get up and running with the PostHog Crystal SDK. The SDK is designed to be async-first, meaning it processes events in the background to ensure your application remains responsive.

## Installation

Add `posthog` to your `shard.yml` dependencies:

```yaml
dependencies:
  posthog:
    github: watzon/posthog.cr
```

Then run:

```bash
shards install
```

## Quick Start

The most basic usage involves initializing a client and capturing an event.

```crystal
require "posthog"

# Initialize the client
posthog = PostHog::Client.new(
  api_key: "your_project_api_key",
  host: "https://us.i.posthog.com" # Optional, defaults to US Cloud
)

# Capture an event
posthog.capture(
  distinct_id: "user_123",
  event: "application_started"
)

# Ensure all events are sent before the program exits
posthog.shutdown
```

## Capturing Events

Events are the core of PostHog. You can send custom properties along with any event.

```crystal
posthog.capture(
  distinct_id: "user_123",
  event: "button_clicked",
  properties: PostHog::Client::Properties{
    "color" => JSON::Any.new("blue"),
    "price" => JSON::Any.new(42.0),
    "is_admin" => JSON::Any.new(false)
  }
)
```

## Identifying Users

Use `identify` to associate a user with their properties. This is typically done after a user logs in.

```crystal
posthog.identify(
  distinct_id: "user_123",
  properties: PostHog::Client::Properties{
    "email" => JSON::Any.new("user@example.com"),
    "plan" => JSON::Any.new("premium"),
    "name" => JSON::Any.new("Jane Doe")
  }
)
```

## Group Analytics

Group analytics allow you to track events at a company or organization level.

```crystal
# Associate a user with a company
posthog.capture(
  distinct_id: "user_123",
  event: "signed_contract",
  groups: {"company" => "acme_inc"}
)

# Identify the company with properties
posthog.group_identify(
  group_type: "company",
  group_key: "acme_inc",
  properties: PostHog::Client::Properties{
    "name" => JSON::Any.new("Acme Inc"),
    "employees" => JSON::Any.new(150.to_i64)
  }
)
```

## Feature Flags

The SDK supports both remote and local evaluation of feature flags.

### Basic Check (Remote Evaluation)

```crystal
if posthog.feature_enabled?("new-dashboard", "user_123")
  # Show the new dashboard
end
```

### Local Evaluation

For high-performance, low-latency applications, you can enable local evaluation by providing a **Personal API Key**. This will poll PostHog for flag definitions and evaluate them locally in your app.

```crystal
posthog = PostHog::Client.new(
  api_key: "your_project_api_key",
  personal_api_key: "your_personal_api_key" # Required for local evaluation
)

# This check is now performed locally
if posthog.feature_enabled?("performance-boost", "user_123")
  # ...
end
```

## Exception Capture

Automatically capture exceptions with full backtraces.

```crystal
begin
  # Some risky operation
  1 / 0
rescue ex
  posthog.capture_exception(ex, distinct_id: "user_123")
end
```

## Lifecycle Management

### Async vs Sync Mode

By default, the SDK operates in **async mode**. Events are placed in a queue and processed by a background fiber.

If you need to send events immediately (e.g., in a short-lived CLI tool), you can use **sync mode**:

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  async: false # Disable background worker
)
```

### Flushing and Shutdown

- `posthog.flush`: Blocks until all currently queued events have been sent.
- `posthog.shutdown`: Flushes the queue and gracefully shuts down the background worker. **Always call this before your program exits.**

## Error Handling

You can provide an `on_error` callback to be notified when the SDK encounters an error (e.g., network failure, validation error).

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  on_error: ->(status : Int32, message : String) {
    Log.error { "PostHog Error (#{status}): #{message}" }
  }
)
```
