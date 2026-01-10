# ExceptionInfo

`struct`

*Defined in [src/posthog/exception_capture.cr:65](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L65)*

Represents an exception in the $exception_list

## Constructors

### `.new(type : String, value : String, mechanism : Mechanism = Mechanism.new, stacktrace : Stacktrace | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L80)*

---

### `.new(pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L66)*

---

### `.new(*, __pull_for_json_serializable pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L66)*

---

## Instance Methods

### `#mechanism`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L75)*

Exception mechanism

---

### `#stacktrace`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L78)*

Stack trace

---

### `#type`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L69)*

Exception type (class name)

---

### `#value`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L72)*

Exception message

---

