# BackoffPolicy

`class`

*Defined in [src/posthog/backoff_policy.cr:19](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L19)*

Exponential backoff policy with jitter for retry logic

Uses the decorrelated jitter algorithm to prevent thundering herd:
https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/

Example:
```
policy = BackoffPolicy.new
attempt = 0
loop do
  break if attempt >= policy.max_retries
  response = make_request()
  break if response.success?
  sleep(policy.next_interval)
  attempt += 1
end
```

## Constructors

### `.new(min : Time::Span = Defaults::BACKOFF_MIN, max : Time::Span = Defaults::BACKOFF_MAX, multiplier : Float64 = Defaults::BACKOFF_MULTIPLIER, max_retries : Int32 = Defaults::MAX_RETRIES)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L27)*

---

## Instance Methods

### `#current_interval`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L64)*

Get the current interval without advancing

---

### `#next_interval`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L38)*

Calculate the next backoff interval with jitter
Uses decorrelated jitter: sleep = min(max, random_between(min, sleep * multiplier))

---

### `#reset`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L54)*

Reset the backoff to initial state

---

### `#should_retry?(attempt : Int32) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/backoff_policy.cr#L59)*

Check if the given attempt number is within retry limit

---

