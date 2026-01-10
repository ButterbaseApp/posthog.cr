# Configuration Guide

This guide covers all the configuration options available in the PostHog Crystal SDK. Proper configuration ensures that your analytics data is captured reliably and efficiently without impacting your application's performance.

## Basic Configuration

The PostHog client can be initialized with just an API key for most use cases. By default, it connects to PostHog Cloud (US).

### PostHog Cloud (US)
```crystal
posthog = PostHog::Client.new(
  api_key: "phc_your_project_api_key"
)
```

### PostHog Cloud (EU)
```crystal
posthog = PostHog::Client.new(
  api_key: "phc_your_project_api_key",
  host: "https://eu.i.posthog.com"
)
```

### Self-Hosted PostHog
```crystal
posthog = PostHog::Client.new(
  api_key: "phc_your_project_api_key",
  host: "https://posthog.yourdomain.com"
)
```

---

## Configuration Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `api_key` | `String` | **Required** | Your PostHog project API key. |
| `host` | `String` | `https://us.i.posthog.com` | The URL of your PostHog instance. |
| `personal_api_key` | `String?` | `nil` | Required for local feature flag evaluation. |
| `async` | `Bool` | `true` | Whether to use a background fiber for processing events. |
| `max_queue_size` | `Int32` | `10,000` | Maximum number of events to queue before dropping new ones. |
| `batch_size` | `Int32` | `100` | Number of events to send in a single batch. |
| `request_timeout` | `Time::Span` | `10.seconds` | Timeout for API requests. |
| `on_error` | `Proc` | `nil` | Callback for handling SDK errors. |
| `before_send` | `Proc` | `nil` | Hook to modify or drop events before they are queued. |
| `test_mode` | `Bool` | `false` | If true, events are queued but never sent to the server. |
| `skip_ssl_verification` | `Bool` | `false` | Skip SSL certificate validation (use only in development). |
| `feature_flags_polling_interval` | `Time::Span` | `30.seconds` | How often to refresh local feature flag definitions. |
| `feature_flag_request_timeout` | `Time::Span` | `3.seconds` | Timeout for feature flag evaluation requests. |

---

## Detailed Configuration

### API Keys: Project vs Personal

PostHog uses two types of API keys:

1.  **Project API Key (`api_key`)**: Used for capturing events and identifying users. It is public and safe to use in frontend applications, though the Crystal SDK is typically used server-side.
2.  **Personal API Key (`personal_api_key`)**: Required for **local evaluation** of feature flags. This key has more permissions and should **never** be exposed publicly.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_project_key",
  personal_api_key: "phx_personal_key" # Enables local evaluation
)
```

### Async vs Sync Mode

-   **Async Mode (Default)**: Events are added to an internal queue and processed by a background fiber. This ensures that `capture` calls return immediately and don't block your main application flow.
-   **Sync Mode**: Events are sent immediately in the same fiber. This is useful for short-lived scripts or CLI tools where you need to ensure the event is sent before the process exits.

```crystal
# Sync mode for a CLI tool
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  async: false
)
```

### Error Handling (`on_error`)

Since the SDK operates asynchronously, errors (like network failures or validation issues) won't raise exceptions in your main fiber. Use the `on_error` callback to monitor and log these issues.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  on_error: ->(status : Int32, message : String) {
    Log.error { "PostHog SDK Error: [#{status}] #{message}" }
  }
)
```

### The `before_send` Hook

The `before_send` hook allows you to inspect, modify, or drop events before they are even added to the queue.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  before_send: ->(event : Hash(String, JSON::Any)) {
    # Drop events from a specific user
    return nil if event["distinct_id"] == "internal_bot"

    # Scrub sensitive data
    if props = event["properties"].as_h?
      props.delete("password")
    end

    event
  }
)
```

### Performance Tuning

For high-volume applications, you may need to tune the batching behavior:

-   **`batch_size`**: Increasing this reduces the number of HTTP requests but increases the size of each request. PostHog limits batches to 500KB.
-   **`max_queue_size`**: If your application generates events faster than they can be sent, the queue will fill up. Once `max_queue_size` is reached, new events are dropped to prevent memory exhaustion.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  batch_size: 250,        # Send more events per request
  max_queue_size: 50_000  # Handle larger bursts of traffic
)
```

### Test Mode

In your test environment, you likely don't want to send real data to PostHog. Enable `test_mode` to keep the SDK operational (queuing events) without making any network requests.

```crystal
# spec/spec_helper.cr
PostHog::Client.new(
  api_key: "test",
  test_mode: true
)
```

### Timeout and Retries

The SDK automatically retries failed requests (5xx server errors or 429 rate limits) using exponential backoff with jitter.

-   **`request_timeout`**: How long to wait for a response from PostHog before timing out (default 10s).
-   **Retries**: The SDK defaults to 10 retries with increasing delays between them.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  request_timeout: 5.seconds # Fail faster on network issues
)
```
