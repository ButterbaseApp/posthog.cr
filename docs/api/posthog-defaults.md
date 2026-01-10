# Defaults

`module`

*Defined in [src/posthog/config.cr:3](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L3)*

Default configuration values

## Constants

### `BACKOFF_MAX`

```crystal
BACKOFF_MAX = 10.seconds
```

### `BACKOFF_MIN`

```crystal
BACKOFF_MIN = 100.milliseconds
```

Backoff policy

### `BACKOFF_MULTIPLIER`

```crystal
BACKOFF_MULTIPLIER = 1.5
```

### `BATCH_SIZE`

```crystal
BATCH_SIZE = 100
```

### `FEATURE_FLAG_REQUEST_TIMEOUT`

```crystal
FEATURE_FLAG_REQUEST_TIMEOUT = 3.seconds
```

### `FEATURE_FLAGS_POLLING_INTERVAL`

```crystal
FEATURE_FLAGS_POLLING_INTERVAL = 30.seconds
```

Feature flags

### `HOST`

```crystal
HOST = "https://us.i.posthog.com"
```

API host defaults

### `MAX_BATCH_BYTES`

```crystal
MAX_BATCH_BYTES = 512000
```

### `MAX_MESSAGE_BYTES`

```crystal
MAX_MESSAGE_BYTES = 32768
```

Message limits

### `MAX_QUEUE_SIZE`

```crystal
MAX_QUEUE_SIZE = 10000
```

Queue settings

### `MAX_RETRIES`

```crystal
MAX_RETRIES = 10
```

### `REQUEST_TIMEOUT`

```crystal
REQUEST_TIMEOUT = 10.seconds
```

Request settings

