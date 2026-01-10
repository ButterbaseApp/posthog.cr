# Stacktrace

`struct`

*Defined in [src/posthog/exception_capture.cr:111](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L111)*

Stacktrace container

## Constructors

### `.new(pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L112)*

---

### `.new(frames : Array(StackFrame) = [] of StackFrame)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L117)*

---

### `.new(*, __pull_for_json_serializable pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L112)*

---

## Instance Methods

### `#frames`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L115)*

Stack frames (most recent first)

---

