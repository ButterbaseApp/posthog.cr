# StackFrame

`struct`

*Defined in [src/posthog/exception_capture.cr:15](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L15)*

Represents a single stack frame in the exception

## Constructors

### `.new(pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L16)*

---

### `.new(filename : String, abs_path : String | Nil = nil, lineno : Int32 | Nil = nil, colno : Int32 | Nil = nil, function : String | Nil = nil, in_app : Bool = false, context_line : String | Nil = nil, pre_context : Array(String) | Nil = nil, post_context : Array(String) | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L50)*

---

### `.new(*, __pull_for_json_serializable pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L16)*

---

## Instance Methods

### `#abs_path`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L23)*

Absolute path to the file

---

### `#colno`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L29)*

Column number

---

### `#context_line`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L40)*

The actual line of code

---

### `#filename`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L19)*

Filename (relative or basename)

---

### `#function`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L32)*

Function name

---

### `#in_app`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L36)*

Whether this frame is in application code (vs stdlib/shards)

---

### `#lineno`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L26)*

Line number

---

### `#post_context`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L48)*

Lines after the error

---

### `#pre_context`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L44)*

Lines before the error

---

