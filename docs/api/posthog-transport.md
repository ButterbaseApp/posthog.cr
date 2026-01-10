# Transport

`class`

*Defined in [src/posthog/transport.cr:26](https://github.com/watzon/posthog.cr/blob/main/src/posthog/transport.cr#L26)*

HTTP transport for sending batches to PostHog

Handles HTTP communication with the PostHog API including:
- Connection management
- Request headers
- Retry logic with exponential backoff
- SSL configuration
- Timeout handling

Example:
```
transport = Transport.new(
  host: "https://us.i.posthog.com",
  timeout: 10.seconds,
  max_retries: 3
)

response = transport.send(api_key, batch)
transport.shutdown
```

## Constants

### `Log`

```crystal
Log = ::Log.for(self)
```

## Constructors

### `.new(host : String, timeout : Time::Span = Defaults::REQUEST_TIMEOUT, skip_ssl_verification : Bool = false, max_retries : Int32 = Defaults::MAX_RETRIES)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/transport.cr#L32)*

---

## Instance Methods

### `#send(api_key : String, batch : MessageBatch) : Response`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/transport.cr#L46)*

Send a batch of messages to PostHog with automatic retry

Returns a Response indicating success or failure.
Automatically retries on 5xx and 429 responses with exponential backoff.

---

### `#send_once(api_key : String, batch : MessageBatch) : Response`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/transport.cr#L79)*

Send a single request without retry logic
Useful for testing or when you want to handle retries yourself

---

### `#shutdown`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/transport.cr#L88)*

Shutdown the transport and close connections

---

