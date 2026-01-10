# Control

`enum`

*Defined in [src/posthog/worker.cr:10](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L10)*

Control message types for the worker

## Constants

### `Flush`

```crystal
Flush = 0
```

### `Shutdown`

```crystal
Shutdown = 1
```

## Instance Methods

### `#flush?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L11)*

Returns `true` if this enum value equals `Flush`

---

### `#shutdown?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L12)*

Returns `true` if this enum value equals `Shutdown`

---

