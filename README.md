# PostHog Crystal SDK

[![Crystal](https://img.shields.io/badge/crystal-%3E%3D1.14-black)](https://crystal-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Crystal-idiomatic PostHog SDK with async-first design, supporting both PostHog Cloud and self-hosted instances.

PostHog is an open-source product analytics platform. This SDK provides event capture, user identification, group analytics, feature flags (with local evaluation), and exception capture—all optimized for Crystal's concurrency model with background fiber workers and channel-based message queuing.

**[📚 Full Documentation](https://posthog-cr-docs.wtz.nz/)**

## Features

- **Async-first Architecture**: Background fiber worker with channel-based queuing
- **Event Capture**: Track user actions, properties, and groups
- **User Identification**: Associate user traits with distinct IDs
- **Feature Flags**: Remote and local evaluation with polling
- **Exception Capture**: Automatic stack trace parsing with source context
- **Batched Transport**: Configurable batch sizes with exponential backoff retry
- **Type Safety**: Full Crystal type system integration

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  posthog:
    github: watzon/posthog.cr
```

Then run:

```sh
shards install
```

## Quick Start

```crystal
require "posthog"

# Initialize the client
posthog = PostHog::Client.new(
  api_key: "your_project_api_key",
  host: "https://us.i.posthog.com"  # or https://eu.i.posthog.com
)

# Capture an event
posthog.capture(
  distinct_id: "user_123",
  event: "button_clicked",
  properties: PostHog::Client::Properties{
    "color" => JSON::Any.new("blue"),
    "price" => JSON::Any.new(42.0)
  }
)

# Identify a user
posthog.identify(
  distinct_id: "user_123",
  properties: PostHog::Client::Properties{
    "email" => JSON::Any.new("user@example.com"),
    "plan" => JSON::Any.new("premium")
  }
)

# Check feature flags
if posthog.feature_enabled?("new-feature", "user_123")
  # New feature code
end

# Capture exceptions
begin
  risky_operation
rescue ex
  posthog.capture_exception(ex, distinct_id: "user_123")
end

# Always shutdown before exit
posthog.shutdown
```

## Documentation

For comprehensive guides, configuration options, and API reference, visit **[posthog-cr-docs.wtz.nz](https://posthog-cr-docs.wtz.nz/)**.

### Guides

- [Getting Started](https://posthog-cr-docs.wtz.nz/guides/getting-started/) - Installation, quick start, and basic usage
- [Configuration](https://posthog-cr-docs.wtz.nz/guides/configuration/) - All configuration options and performance tuning
- [Feature Flags](https://posthog-cr-docs.wtz.nz/guides/feature-flags/) - Remote and local evaluation, variants, payloads
- [Exception Capture](https://posthog-cr-docs.wtz.nz/guides/exception-capture/) - Error tracking with stack traces

### API Reference

- [PostHog::Client](https://posthog-cr-docs.wtz.nz/api/) - Main client API
- [Configuration](https://posthog-cr-docs.wtz.nz/api/posthog-config/) - Config class reference
- [Feature Flags](https://posthog-cr-docs.wtz.nz/api/posthog-featureflags/) - Feature flag API

## Development

```sh
# Install dependencies
shards install

# Run tests
crystal spec

# Format code
crystal tool format
```

## Contributing

1. Fork it (<https://github.com/watzon/posthog.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer
