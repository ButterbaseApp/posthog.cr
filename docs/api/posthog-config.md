# Config

`class`

*Defined in [src/posthog/config.cr:30](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L30)*

Client configuration

## Constructors

### `.new(api_key : String, host : String = Defaults::HOST, personal_api_key : String | Nil = nil, max_queue_size : Int32 = Defaults::MAX_QUEUE_SIZE, batch_size : Int32 = Defaults::BATCH_SIZE, request_timeout : Time::Span = Defaults::REQUEST_TIMEOUT, skip_ssl_verification : Bool = false, async : Bool = true, test_mode : Bool = false, feature_flags_polling_interval : Time::Span = Defaults::FEATURE_FLAGS_POLLING_INTERVAL, feature_flag_request_timeout : Time::Span = Defaults::FEATURE_FLAG_REQUEST_TIMEOUT, on_error : Proc(Int32, String, Nil) | Nil = nil, before_send : BeforeSendProc | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L72)*

---

## Instance Methods

### `#api_key`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L32)*

Required: Your PostHog project API key

---

### `#async`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L53)*

Whether to use async mode (background fiber) or sync mode

---

### `#batch_size`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L44)*

Number of messages to send in each batch

---

### `#feature_flag_request_timeout`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L62)*

Feature flag request timeout

---

### `#feature_flags_polling_interval`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L59)*

Feature flags polling interval

---

### `#host`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L35)*

API host (PostHog Cloud US, EU, or self-hosted)

---

### `#max_queue_size`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L41)*

Maximum number of messages to queue before dropping

---

### `#normalized_host`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L91)*

Normalize host URL (remove trailing slash)

---

### `#on_error`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L65)*

Error callback - called when an error occurs

---

### `#personal_api_key`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L38)*

Personal API key for local feature flag evaluation

---

### `#request_timeout`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L47)*

Request timeout for API calls

---

### `#skip_ssl_verification`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L50)*

Whether to skip SSL verification (development only)

---

### `#test_mode`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/config.cr#L56)*

Test mode - when true, messages are queued but not sent

---

## Nested Types

- [`BeforeSendProc`](posthog-config-beforesendproc.md) - <p>Before send hook - can modify or drop events Return the modified event, or nil to drop it</p>

