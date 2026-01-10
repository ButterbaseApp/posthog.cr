# POSTHOG.CR — CRYSTAL SDK

**Generated:** 2026-01-10
**Commit:** c66b632
**Branch:** main

## OVERVIEW

Crystal SDK for PostHog analytics. Async-first design with background fiber worker, batched HTTP transport, and channel-based message queuing.

## STRUCTURE

```
posthog.cr/
├── src/
│   ├── posthog.cr          # Entry point, requires all modules
│   └── posthog/
│       ├── client.cr       # Main API: capture, identify, alias, group_identify
│       ├── worker.cr       # Background fiber, batch processing
│       ├── transport.cr    # HTTP client, retries, error handling
│       ├── message.cr      # Message struct, MessageBatch for batching
│       ├── config.cr       # Config class, Defaults module
│       ├── field_parser.cr # Input validation, message construction
│       ├── utils.cr        # UUID, ISO8601, SHA1 hashing
│       └── version.cr      # VERSION constant
├── spec/
│   ├── spec_helper.cr      # MockTransport, create_test_client(), props()
│   └── posthog/            # Mirrors src/ structure
└── shard.yml               # Crystal >= 1.18.2, MIT license
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new event type | `field_parser.cr` | Add `parse_for_X` method, follow existing pattern |
| Modify batching logic | `worker.cr` | `run_loop`, `drain_and_send` |
| Change HTTP behavior | `transport.cr` | `send`, retry logic in `should_retry?` |
| Add config option | `config.cr` | Add to `Config` class + `Defaults` module |
| Test helpers | `spec/spec_helper.cr` | `MockTransport`, `create_test_client` |

## ARCHITECTURE

```
Client                    Worker (fiber)              Transport
   │                          │                          │
   ├─ enqueue(Message) ──────►│                          │
   │  via @message_channel    │                          │
   │                          ├─ batch messages          │
   │                          ├─ when full/flush ───────►│
   │                          │                          ├─ POST /batch
   │                          │◄─────── response ────────┤
   │                          │                          │
   ├─ flush() ───────────────►│ (Control::Flush)         │
   ├─ shutdown() ────────────►│ (Control::Shutdown)      │
```

- **Async mode (default):** Messages queued via `Channel(Message)`, processed by background fiber
- **Sync mode:** Direct `transport.send` in `enqueue`
- **Test mode:** Messages accepted but not sent

## CONVENTIONS

- **Properties type:** `Hash(String, JSON::Any)` throughout
- **Error handling:** `on_error` callback, never raises from public methods
- **Logging:** `Log.for(self)` pattern in each class
- **Validation:** `FieldParser.validate_presence!` raises `ValidationError`
- **Time format:** ISO8601 via `Utils.iso8601(Time)`

## ANTI-PATTERNS

- **DO NOT** use `as any` or skip type safety
- **DO NOT** block the main fiber with sync HTTP in async mode
- **DO NOT** access `@worker` directly from tests (use `queue_size`, `flush`)

## TECHNICAL DEBT

- `TODO` in `client.cr:81`: Implement `send_feature_flags` (Phase 3)
- No CI/CD configured (missing `.github/workflows/`)
- README contains placeholder TODOs

## COMMANDS

```bash
# Install dependencies
shards install

# Run tests
crystal spec

# Run specific test
crystal spec spec/posthog/client_spec.cr

# Format code
crystal tool format

# Check types
crystal build --no-codegen src/posthog.cr
```

## NOTES

- Requires Crystal >= 1.18.2
- No external dependencies beyond stdlib
- `MessageBatch` enforces 32KB/message and 500KB/batch limits
- Worker uses `select` for non-blocking channel receives
