# Mechanism

`struct`

*Defined in [src/posthog/exception_capture.cr:90](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L90)*

Mechanism for how the exception was captured

## Constructors

### `.new(pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L91)*

---

### `.new(type : String = "generic", handled : Bool = true, synthetic : Bool = false)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L102)*

---

### `.new(*, __pull_for_json_serializable pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L91)*

---

## Instance Methods

### `#handled`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L97)*

Whether the exception was handled

---

### `#synthetic`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L100)*

Whether this is a synthetic exception

---

### `#type`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/exception_capture.cr#L94)*

Mechanism type (always "generic" for manual captures)

---

