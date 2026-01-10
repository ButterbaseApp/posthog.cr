# ExceptionCapture

`module`

*Defined in [src/posthog/exception_capture.cr:5](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L5)*

Exception capture module for serializing exceptions into PostHog $exception events

## Constants

### `CONTEXT_LINES`

```crystal
CONTEXT_LINES = 5
```

Number of context lines to include before and after the error line

### `MAX_FRAMES`

```crystal
MAX_FRAMES = 50
```

Maximum number of stack frames to include

## Instance Methods

### `#parse_exception(exception : Exception, handled : Bool = true) : Hash(String, JSON::Any)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L130)*

Parse an exception into properties for a $exception event

```
begin
  risky_operation
rescue ex
  properties = ExceptionCapture.parse_exception(ex)
end
```

---

### `#parse_message(message : String) : Hash(String, JSON::Any)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L142)*

Parse a string message into properties for a $exception event (no backtrace)

---

## Nested Types

- [`ExceptionInfo`](posthog-exceptioncapture-exceptioninfo.md) - <p>Represents an exception in the $exception_list</p>
- [`Mechanism`](posthog-exceptioncapture-mechanism.md) - <p>Mechanism for how the exception was captured</p>
- [`StackFrame`](posthog-exceptioncapture-stackframe.md) - <p>Represents a single stack frame in the exception</p>
- [`Stacktrace`](posthog-exceptioncapture-stacktrace.md) - <p>Stacktrace container</p>

