# API Reference

Complete API documentation for PostHog Crystal SDK, auto-generated from source code.

## Modules

- [`Defaults`](posthog-defaults.md) - <p>Default configuration values</p>
- [`ExceptionCapture`](posthog-exceptioncapture.md) - <p>Exception capture module for serializing exceptions into PostHog $exception events</p>
- [`FieldParser`](posthog-fieldparser.md) - <p>Parses and validates input fields, producing normalized Message objects</p>

## Classes

- [`BackoffPolicy`](posthog-backoffpolicy.md) - <p>Exponential backoff policy with jitter for retry logic</p>
- [`Client`](posthog-client.md) - <p>The main PostHog client for capturing events and managing feature flags</p>
- [`Config`](posthog-config.md) - <p>Client configuration</p>
- [`FeatureFlagsClient`](posthog-featureflagsclient.md) - <p>Feature flags client with support for both local and remote evaluation.</p>
- [`MessageBatch`](posthog-messagebatch.md) - <p>A batch of messages ready to be sent</p>
- [`Transport`](posthog-transport.md) - <p>HTTP transport for sending batches to PostHog</p>
- [`Worker`](posthog-worker.md) - <p>Background fiber worker that consumes messages from the queue and sends them to PostHog in batches</p>

## Structs

- [`ExceptionInfo`](posthog-exceptioncapture-exceptioninfo.md) - <p>Represents an exception in the $exception_list</p>
- [`FeatureFlagCalledEvent`](posthog-featureflagsclient-featureflagcalledevent.md) - <p>Event data for $feature_flag_called</p>
- [`Mechanism`](posthog-exceptioncapture-mechanism.md) - <p>Mechanism for how the exception was captured</p>
- [`Message`](posthog-message.md) - <p>Represents a message to be sent to PostHog</p>
- [`Response`](posthog-response.md) - <p>Response from the transport layer</p>
- [`StackFrame`](posthog-exceptioncapture-stackframe.md) - <p>Represents a single stack frame in the exception</p>
- [`Stacktrace`](posthog-exceptioncapture-stacktrace.md) - <p>Stacktrace container</p>

## Enums

- [`BatchAddResult`](posthog-batchaddresult.md) - <p>Result of attempting to add a message to a batch</p>
- [`Control`](posthog-worker-control.md) - <p>Control message types for the worker</p>

