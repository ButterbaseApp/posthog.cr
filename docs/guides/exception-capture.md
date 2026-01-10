# Exception Capture Guide

PostHog's Crystal SDK provides automatic and manual exception tracking to help you monitor application health and debug issues directly within PostHog. This guide explains how to capture exceptions, customize the data sent, and integrate with popular Crystal web frameworks.

## Introduction to Exception Tracking

Tracking exceptions in PostHog allows you to:
- **Correlate errors with user behavior**: See what a user was doing right before an error occurred.
- **Prioritize fixes**: Focus on errors affecting the most users or high-value accounts.
- **Deep Debugging**: Get full backtraces and source code context without leaving PostHog.

Exceptions are sent to PostHog as `$exception` events.

## Basic Usage

The simplest way to capture an exception is using the `capture_exception` method on the `PostHog::Client`.

```crystal
require "posthog"

posthog = PostHog::Client.new(api_key: "phc_xxx")

begin
  # Some risky operation
  1 / 0
rescue ex
  posthog.capture_exception(ex, distinct_id: "user_123")
end
```

### Capturing from String Messages

If you want to track an error that isn't an `Exception` object (e.g., a logic error that doesn't raise), you can pass a string message. Note that this will not include a backtrace.

```crystal
posthog.capture_exception("Payment failed for user", distinct_id: "user_123")
```

## Stack Trace Details and Parsing

When you capture an `Exception` object, the SDK automatically parses the Crystal backtrace into a format PostHog understands.

### Frame Parsing
Each frame in the stack trace includes:
- **Filename**: The name of the source file.
- **Absolute Path**: The full path to the file on the server.
- **Line Number**: The exact line where the error occurred.
- **Function**: The method or function name.

### In-App Detection
The SDK distinguishes between your application code and third-party libraries (shards or the Crystal standard library). This allows PostHog to highlight frames that are most relevant to your code.
- Frames in `lib/`, `shards/`, or the Crystal stdlib are marked as `in_app: false`.
- Frames in your project directory are marked as `in_app: true`.

### Source Code Context
If the source file is available on the machine running the SDK, it will extract **11 lines of context**:
- The error line itself.
- 5 lines before the error.
- 5 lines after the error.

This provides immediate context for the crash in the PostHog UI.

## Exception Properties and Custom Data

You can add custom properties to an exception event to provide more context, such as request IDs, user roles, or application state.

```crystal
posthog.capture_exception(
  ex,
  distinct_id: "user_123",
  properties: PostHog::Client::Properties{
    "request_id" => JSON::Any.new("req_abc123"),
    "cart_total" => JSON::Any.new(45.99),
    "feature_flag" => JSON::Any.new("new_checkout_v2")
  }
)
```

## Distinct ID Handling

While it's best to provide a `distinct_id` to correlate the error with a specific user, it is optional for `capture_exception`.

- **If provided**: The error is linked to that user.
- **If missing**: The SDK generates a random UUID for the `distinct_id` and sets `$process_person_profile: false`. This ensures the error is captured without creating "ghost" users in your PostHog person list.

## Web Framework Integration

Integrating PostHog exception capture into your web framework is the best way to ensure all unhandled crashes are tracked.

### Kemal

In Kemal, you can use the `error` block or a custom handler.

```crystal
require "kemal"
require "posthog"

posthog = PostHog::Client.new(api_key: "phc_xxx")

error 500 do |env, ex|
  posthog.capture_exception(
    ex,
    distinct_id: env.params.query["user_id"]?, # If available
    properties: PostHog::Client::Properties{
      "path" => JSON::Any.new(env.request.path),
      "method" => JSON::Any.new(env.request.method)
    }
  )
  "Internal Server Error"
end
```

### Lucky

In Lucky, you can integrate with the `Errors::Handler`.

```crystal
# src/handlers/error_handler.cr
class ErrorHandler < Lucky::ErrorHandler
  def action(context, ex)
    PostHogClient.capture_exception(ex)
    super
  end
end
```

### Amber

In Amber, you can add a custom error handler in your pipeline.

```crystal
# src/pipes/error_handler.cr
class PostHogErrorHandler < Amber::Pipe::Base
  def call(context)
    call_next(context)
  rescue ex : Exception
    PostHogClient.capture_exception(ex, properties: {
      "url" => JSON::Any.new(context.request.url)
    })
    raise ex
  end
end
```

## Fiber Error Handling

Crystal is fiber-based. If an exception occurs in a background fiber, it may crash the fiber without being caught by your main application loop.

```crystal
spawn do
  begin
    do_something_heavy
  rescue ex
    posthog.capture_exception(ex)
    # Re-raise if you want the fiber to die, or handle gracefully
  end
end
```

## Best Practices for Production

1. **Always call `shutdown`**: Ensure you call `posthog.shutdown` when your application exits to flush any pending exception events.
2. **Use `on_error`**: Configure an `on_error` callback during initialization to track if the SDK itself fails to send an event.
3. **Don't over-log**: Avoid capturing exceptions in tight loops. Use rate limiting or deduplication if necessary (though PostHog handles some of this for you).
4. **Sensitive Data**: Be careful not to include personally identifiable information (PII) in exception properties or messages. The SDK extracts source lines, so ensure your source code doesn't contain hardcoded secrets.
5. **Async Mode**: Keep the default `async: true` for web applications to ensure exception reporting doesn't slow down your response times.
