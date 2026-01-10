# Response

`struct`

*Defined in [src/posthog/response.cr:18](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L18)*

Response from the transport layer

Encapsulates HTTP response status, body, and error information.
Provides helpers for determining success and retry eligibility.

Example:
```
response = transport.send(api_key, batch)
if response.success?
  puts "Batch sent successfully"
elsif response.should_retry?
  puts "Temporary error, will retry"
else
  puts "Permanent error: #{response.error}"
end
```

## Constructors

### `.network_error(error : String) : Response`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L106)*

Create a network error response

---

### `.new(status : Int32, body : String = "", error : String | Nil = nil, retry_after : Time::Span | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L31)*

---

### `.success(body : String = "") : Response`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L101)*

Create a success response

---

### `.timeout_error`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L111)*

Create a timeout error response

---

## Instance Methods

### `#body`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L23)*

Response body from the server

---

### `#client_error?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L60)*

Check if this is a client error (4xx, excluding 429)

---

### `#error`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L26)*

Error message for failed requests

---

### `#error_message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L75)*

Get a human-readable error message

---

### `#network_error?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L70)*

Check if this is a network/connection error

---

### `#rate_limited?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L55)*

Check if this is a rate limit response

---

### `#retry_after`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L29)*

Retry-After header value in seconds (for 429 responses)

---

### `#server_error?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L65)*

Check if this is a server error (5xx)

---

### `#should_retry?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L50)*

Check if the request should be retried

Retryable conditions:
- 5xx server errors
- 429 rate limit
- Network errors (status -1)

---

### `#status`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L20)*

HTTP status code, or -1 for network/connection errors

---

### `#success?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/response.cr#L40)*

Check if the request was successful (2xx status)

---

