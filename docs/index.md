# PostHog Crystal SDK

[![Shard Version](https://img.shields.io/github/v/release/watzon/posthog.cr)](https://github.com/watzon/posthog.cr/releases)
[![Build Status](https://github.com/watzon/posthog.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/watzon/posthog.cr/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The **PostHog Crystal SDK** is a high-performance, async-first analytics client designed specifically for the Crystal programming language. It allows you to seamlessly integrate [PostHog](https://posthog.com) into your Crystal applications with minimal impact on application latency.

---

## Why use the Crystal SDK?

*   **⚡ Async-First Design**: Built on Crystal's concurrency model. Events are queued and processed in a background fiber, ensuring your main application loop remains responsive.
*   **🛠️ Local Evaluation**: Evaluate feature flags locally with zero-latency decisions by providing a Personal API Key.
*   **🚨 Exception Capture**: Automatically capture exceptions with full backtraces and context, making debugging easier.
*   **📦 Batched Transport**: Efficiently sends events in batches to reduce HTTP overhead and improve throughput.
*   **💎 Crystal-Idiomatic**: Type-safe API with named parameters and ergonomic syntax.

---

## Installation

Add `posthog` to your `shard.yml` dependencies:

```yaml
dependencies:
  posthog:
    github: watzon/posthog.cr
```

Then install your dependencies:

```bash
shards install
```

---

## Quick Start

Initialize the client and capture your first event in seconds.

```crystal
require "posthog"

# Initialize the client
posthog = PostHog::Client.new(
  api_key: "your_project_api_key",
  host: "https://us.i.posthog.com" # Defaults to US Cloud
)

# Capture an event
posthog.capture(
  distinct_id: "user_123",
  event: "application_started",
  properties: {"plan" => "pro"}
)

# Always call shutdown before your program exits to flush the queue
posthog.shutdown
```

---

## Core Features

| Feature | Description |
| :--- | :--- |
| **Event Capture** | Track custom events with rich metadata and group associations. |
| **User Identification** | Connect user identities and traits across sessions. |
| **Feature Flags** | Control feature rollouts with remote or local evaluation. |
| **Group Analytics** | Track metrics at the company or organization level. |
| **Exception Tracking** | Capture crashes and errors with source-mapped stack traces. |

---

## Architecture Overview

The SDK utilizes a **Channel-based background worker** system:

1.  **Client**: When you call `.capture`, the event is validated and immediately pushed onto a thread-safe `Channel`.
2.  **Worker Fiber**: A background fiber continuously drains the channel, batching messages based on your configuration.
3.  **Transport**: Batched messages are sent to PostHog via a resilient HTTP transport with automatic retries and exponential backoff.

This design ensures that your application never blocks on network I/O during analytics tracking.

---

## Documentation & Guides

Explore our detailed guides to get the most out of the SDK:

*   [**Getting Started**](./guides/getting-started.md) - A comprehensive tutorial to get you up and running.
*   [**Configuration**](./guides/configuration.md) - Deep dive into all available client options.
*   [**Feature Flags**](./guides/feature-flags.md) - Learn about remote vs local evaluation and variants.
*   [**Exception Capture**](./guides/exception-capture.md) - How to track application errors effectively.
*   [**API Reference**](./api/index.html) - Detailed technical documentation for all classes and methods.

---

## Community & Support

*   [PostHog Documentation](https://posthog.com/docs)
*   [GitHub Issues](https://github.com/watzon/posthog.cr/issues)
*   [PostHog Slack Community](https://posthog.com/slack)
