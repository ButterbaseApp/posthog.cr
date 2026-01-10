# PostHog Crystal SDK Roadmap

A Crystal-idiomatic PostHog SDK with async-first design, supporting both PostHog Cloud and self-hosted instances.

**Target Crystal Version:** Current stable (1.14+)  
**Architecture:** Background fiber worker using `Channel` for async event processing

---

## Phase 1 — Core Async Capture (MVP)

The foundation: async event capture with background fiber worker.

### Module Structure
- [x] `src/posthog.cr` — Main entry point with convenience methods
- [x] `src/posthog/version.cr` — Version constant
- [x] `src/posthog/client.cr` — Primary `PostHog::Client` class
- [x] `src/posthog/config.cr` — Configuration and defaults
- [x] `src/posthog/field_parser.cr` — Payload normalization
- [x] `src/posthog/worker.cr` — Background fiber worker (includes queue via Channel)
- [x] `src/posthog/message.cr` — Message struct for queue
- [x] `src/posthog/utils.cr` — UUID generation, time formatting
- [x] `src/posthog/transport.cr` — Basic HTTP transport

### Client API
- [x] `Client.new(api_key, host, **options)` — Initialize with config
- [x] `capture(distinct_id, event, properties, groups, timestamp)` — Capture events
- [x] `identify(distinct_id, properties)` — Identify users with `$set`
- [x] `alias(distinct_id, alias_id)` — Create user alias (`$create_alias`)
- [x] `group_identify(group_type, group_key, properties, distinct_id)` — Identify groups (`$groupidentify`)

### Configuration Options
- [x] `api_key : String` — Project API key (required)
- [x] `host : String` — API host (default: `https://us.i.posthog.com`)
- [x] `max_queue_size : Int32` — Queue limit before dropping (default: 10_000)
- [x] `batch_size : Int32` — Messages per batch (default: 100)
- [x] `on_error : Proc` — Error callback
- [x] `before_send : Proc` — Modify/drop events before queuing
- [x] `test_mode : Bool` — Test mode for specs

### Payload Normalization
- [x] Auto-generate `messageId` (UUID v4)
- [x] Convert timestamps to ISO8601
- [x] Inject `$lib` and `$lib_version` properties
- [x] Handle `$groups` property for group analytics
- [x] Validate required fields (`distinct_id`, `event`)

### Lifecycle Management
- [x] `flush` — Block until queue is empty
- [x] `shutdown` — Graceful shutdown of worker fiber
- [x] Queue overflow handling with `on_error` callback

### Tests (Phase 1)
- [x] Field parser: capture, identify, alias, group_identify payloads
- [x] Required field validation errors
- [x] Timestamp ISO8601 conversion
- [x] Queue overflow behavior
- [x] `before_send` hook (modify, drop, error handling)
- [x] `flush` and `shutdown` lifecycle
- [x] Worker fiber processes messages correctly

---

## Phase 2 — Transport Hardening

Production-ready HTTP transport with retries, timeouts, and testability.

### HTTP Transport
- [x] `src/posthog/transport.cr` — HTTP adapter abstraction
- [x] `src/posthog/backoff_policy.cr` — Exponential backoff with jitter
- [x] `src/posthog/message_batch.cr` — Batch with size limits
- [x] `src/posthog/response.cr` — Response wrapper

### Transport Features
- [x] POST to `/batch` endpoint with JSON payload
- [x] `Content-Type: application/json` header
- [x] `User-Agent: posthog-crystal/{version}` header
- [x] Configurable request timeout (default: 10s)
- [x] `skip_ssl_verification` option for development

### Retry Policy
- [x] Retry on 5xx server errors
- [x] Retry on 429 rate limit
- [x] No retry on 4xx client errors (except 429)
- [x] Exponential backoff: min 100ms, max 10s, multiplier 1.5
- [x] Jitter to prevent thundering herd
- [x] Max retries (default: 10)

### Batch Limits
- [x] Max message size: 32KB
- [x] Max batch size: 500KB
- [x] Max messages per batch: 100
- [x] Drop oversized messages with warning

### Sync Mode
- [x] `async : Bool` option (default: true)
- [x] When `async: false`, send immediately without queue

### Tests (Phase 2)
- [x] Transport sends correct headers and payload shape
- [x] Retry on 5xx and 429
- [x] No retry on 400, 401, 403, 404
- [x] Backoff timing and jitter
- [x] Request timeout handling
- [x] SSL skip option
- [x] Sync mode behavior
- [x] Batch size limit enforcement
- [x] Oversized message handling

---

## Phase 3 — Feature Flags (Remote Evaluation)

Server-side feature flag evaluation via `/flags` API.

### Module Structure
- [ ] `src/posthog/feature_flags.cr` — Feature flag client
- [ ] `src/posthog/feature_flags/response.cr` — API response types

### Feature Flag API
- [ ] `feature_enabled?(key, distinct_id, **opts) : Bool?` — Check if flag enabled
- [ ] `feature_flag(key, distinct_id, **opts) : String | Bool | Nil` — Get flag value/variant
- [ ] `all_flags(distinct_id, **opts) : Hash` — Get all flags for user
- [ ] `feature_flag_payload(key, distinct_id, **opts) : JSON::Any?` — Get flag payload
- [ ] `all_flags_and_payloads(distinct_id, **opts) : NamedTuple` — Get all flags and payloads

### Options for Flag Methods
- [ ] `groups : Hash` — Group memberships
- [ ] `person_properties : Hash` — Person properties for evaluation
- [ ] `group_properties : Hash` — Group properties for evaluation
- [ ] `only_evaluate_locally : Bool` — Skip server fallback

### Integration with Capture
- [ ] `send_feature_flags` option on `capture`
- [ ] Inject `$feature/{flag_key}` properties
- [ ] Inject `$active_feature_flags` array

### Feature Flag Events
- [ ] Emit `$feature_flag_called` event on flag evaluation
- [ ] Include `$feature_flag`, `$feature_flag_response`, `locally_evaluated`
- [ ] Deduplicate events per distinct_id + flag + response

### Tests (Phase 3)
- [ ] Parse v3 and v4 API response formats
- [ ] `feature_enabled?` returns correct boolean
- [ ] `feature_flag` returns variant strings
- [ ] `all_flags` aggregates correctly
- [ ] `send_feature_flags` injects properties into capture
- [ ] `$feature_flag_called` event emission
- [ ] Event deduplication
- [ ] Error handling (timeout, connection errors)

---

## Phase 4 — Feature Flags (Local Evaluation + Polling)

Client-side feature flag evaluation for low-latency decisions.

### Module Structure
- [ ] `src/posthog/feature_flags/poller.cr` — Background polling fiber
- [ ] `src/posthog/feature_flags/local_evaluator.cr` — Local evaluation engine
- [ ] `src/posthog/feature_flags/property_matcher.cr` — Property matching operators
- [ ] `src/posthog/feature_flags/cohort_matcher.cr` — Cohort evaluation
- [ ] `src/posthog/feature_flags/hash.cr` — Consistent hashing for rollouts

### Configuration
- [ ] `personal_api_key : String` — Required for local evaluation
- [ ] `feature_flags_polling_interval : Int32` — Polling interval (default: 30s)
- [ ] `feature_flag_request_timeout : Int32` — Timeout for flag requests (default: 3s)

### Polling
- [ ] Poll `/api/feature_flag/local_evaluation` endpoint
- [ ] ETag support for cache validation (304 Not Modified)
- [ ] Store flags, group type mapping, cohorts
- [ ] `reload_feature_flags` manual refresh method

### Property Matching Operators
- [ ] `exact` — Exact match (case-insensitive)
- [ ] `is_not` — Not equal
- [ ] `is_set` — Property exists
- [ ] `is_not_set` — Property does not exist
- [ ] `icontains` — Case-insensitive contains
- [ ] `not_icontains` — Does not contain
- [ ] `regex` — Regular expression match
- [ ] `not_regex` — Does not match regex
- [ ] `gt`, `gte`, `lt`, `lte` — Numeric/string comparisons
- [ ] `is_date_before`, `is_date_after` — Date comparisons
- [ ] Relative date parsing (`-6h`, `1d`, `1w`, `1m`, `1y`)

### Advanced Evaluation
- [ ] Cohort matching (AND/OR groups)
- [ ] Group type flags (aggregation by group)
- [ ] Flag dependency chains
- [ ] Multivariate rollout percentages
- [ ] Consistent hashing for variant assignment

### Quota and Error Handling
- [ ] Handle 402 quota limit response
- [ ] `InconclusiveMatchError` for missing properties
- [ ] `RequiresServerEvaluation` for static cohorts
- [ ] Fallback to server evaluation when local fails

### Remote Config
- [ ] `remote_config_payload(flag_key)` — Get decrypted payload

### Tests (Phase 4)
- [ ] Polling fetches and stores flag definitions
- [ ] ETag prevents redundant downloads
- [ ] All property operators match correctly
- [ ] Relative date parsing
- [ ] Cohort AND/OR logic
- [ ] Group flag evaluation
- [ ] Dependency chain resolution
- [ ] Consistent hash distribution
- [ ] Variant rollout percentages
- [ ] Quota limit handling
- [ ] Server fallback on inconclusive match
- [ ] Static cohort triggers server evaluation

---

## Phase 5 — Exception Capture

Automatic exception tracking with stack traces.

### Module Structure
- [ ] `src/posthog/exception_capture.cr` — Exception serialization

### API
- [ ] `capture_exception(exception, distinct_id?, properties?)` — Capture exception event

### Exception Payload
- [ ] Event type: `$exception`
- [ ] `$exception_list` array with exception details
- [ ] Exception `type` (class name)
- [ ] Exception `value` (message)
- [ ] `mechanism` with `type: "generic"`, `handled: true`

### Stack Trace Parsing
- [ ] Parse Crystal backtrace format
- [ ] Extract `filename`, `abs_path`, `lineno`, `function`
- [ ] Determine `in_app` (filter out stdlib/shards)
- [ ] Limit to 50 frames
- [ ] Reverse order (most recent first)

### Context Lines
- [ ] Read source file for context (if available)
- [ ] `context_line` — The error line
- [ ] `pre_context` — 5 lines before
- [ ] `post_context` — 5 lines after

### Edge Cases
- [ ] String message input (no backtrace)
- [ ] Missing distinct_id (generate UUID, set `$process_person_profile: false`)
- [ ] File read errors (skip context silently)

### Tests (Phase 5)
- [ ] Exception with full backtrace
- [ ] String message input
- [ ] Missing distinct_id handling
- [ ] Stack frame parsing
- [ ] Context line extraction
- [ ] In-app detection
- [ ] Frame limit (50)
- [ ] File not found handling

---

## Phase 6 — Documentation and Polish

Production readiness, documentation, and release automation.

### Documentation
- [ ] Comprehensive README with examples
- [ ] API documentation (Crystal doc comments)
- [ ] Configuration guide (Cloud vs self-hosted)
- [ ] Feature flags usage guide
- [ ] Migration guide from other SDKs

### Examples
- [ ] Basic capture example
- [ ] User identification flow
- [ ] Group analytics example
- [ ] Feature flags example
- [ ] Exception capture example
- [ ] Rails/Lucky/Amber integration examples

### Production Readiness
- [ ] Thread safety audit
- [ ] Memory leak testing
- [ ] Performance benchmarks
- [ ] Graceful degradation on errors

### Release Process
- [ ] Semantic versioning
- [ ] CHANGELOG.md maintenance
- [ ] GitHub Actions CI
- [ ] Automatic shard publishing

### Compatibility
- [ ] Document minimum Crystal version
- [ ] Test on multiple Crystal versions
- [ ] Document self-hosted compatibility

---

## File Structure (Final)

```
src/
  posthog.cr                          # Main entry, convenience methods
  posthog/
    version.cr                        # VERSION constant
    client.cr                         # PostHog::Client
    config.cr                         # Configuration, defaults
    field_parser.cr                   # Payload normalization
    queue.cr                          # Channel-based queue
    worker.cr                         # Background fiber worker
    message.cr                        # Message struct
    transport.cr                      # HTTP adapter
    backoff_policy.cr                 # Retry logic
    message_batch.cr                  # Batch sizing
    response.cr                       # API response wrapper
    utils.cr                          # UUID, time helpers
    exception_capture.cr              # Exception serialization
    feature_flags/
      feature_flags.cr                # Main feature flag client
      poller.cr                       # Background polling
      local_evaluator.cr              # Local evaluation engine
      property_matcher.cr             # Property operators
      cohort_matcher.cr               # Cohort logic
      hash.cr                         # Consistent hashing
      response.cr                     # Flag response types
      errors.cr                       # InconclusiveMatchError, etc.

spec/
  spec_helper.cr
  posthog/
    client_spec.cr
    field_parser_spec.cr
    queue_spec.cr
    worker_spec.cr
    transport_spec.cr
    backoff_policy_spec.cr
    message_batch_spec.cr
    exception_capture_spec.cr
    feature_flags/
      feature_flags_spec.cr
      local_evaluator_spec.cr
      property_matcher_spec.cr
      cohort_matcher_spec.cr
      hash_spec.cr
  support/
    mock_transport.cr                 # HTTP stubbing for tests
```

---

## API Quick Reference

```crystal
# Initialize
posthog = PostHog::Client.new(
  api_key: "phc_xxx",
  host: "https://us.i.posthog.com",  # or eu, or self-hosted
  personal_api_key: "phx_xxx",       # for local flag eval
  on_error: ->(status, error) { Log.error { error } }
)

# Capture event
posthog.capture(
  distinct_id: "user_123",
  event: "button_clicked",
  properties: {"color" => "blue"},
  groups: {"company" => "acme_inc"}
)

# Identify user
posthog.identify(
  distinct_id: "user_123",
  properties: {"email" => "user@example.com", "plan" => "premium"}
)

# Alias users
posthog.alias(distinct_id: "user_123", alias_id: "anon_456")

# Group identify
posthog.group_identify(
  group_type: "company",
  group_key: "acme_inc",
  properties: {"name" => "Acme Inc", "employees" => 50}
)

# Feature flags
enabled = posthog.feature_enabled?("new-feature", "user_123")
variant = posthog.feature_flag("experiment", "user_123")
all_flags = posthog.all_flags("user_123")

# Exception capture
begin
  risky_operation
rescue ex
  posthog.capture_exception(ex, distinct_id: "user_123")
end

# Lifecycle
posthog.flush    # Wait for queue to drain
posthog.shutdown # Graceful shutdown
```

---

## Notes

- **Async by default**: All capture methods return immediately; events are processed by background fiber.
- **Crystal-idiomatic**: Uses `feature_enabled?` (not `is_feature_enabled`), named parameters, proper Crystal types.
- **Self-hosted support**: Configure `host` to point to your PostHog instance.
- **Local evaluation**: Requires `personal_api_key` for low-latency feature flag decisions.
- **Graceful degradation**: SDK should never crash your application; all errors go to `on_error` callback.
