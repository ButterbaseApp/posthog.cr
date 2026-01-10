# Message

`struct`

*Defined in [src/posthog/message.cr:5](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L5)*

Represents a message to be sent to PostHog

## Constructors

### `.new(type : String, event : String, distinct_id : String, timestamp : String, message_id : String, properties : Hash(String, JSON::Any), library : String = "posthog-crystal", library_version : String = VERSION, set_properties : Hash(String, JSON::Any) | Nil = nil, uuid : String | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L42)*

---

### `.new(pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L6)*

---

### `.new(*, __pull_for_json_serializable pull : JSON::PullParser)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L6)*

---

## Instance Methods

### `#byte_size`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L57)*

Calculate the JSON byte size of this message

---

### `#distinct_id`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L16)*

Unique ID for this user

---

### `#event`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L12)*

The event name (for capture) or special event like $identify

---

### `#library`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L33)*

Library metadata

---

### `#library_version`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L36)*

Library version

---

### `#message_id`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L23)*

Unique message ID for deduplication

---

### `#properties`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L26)*

Event properties

---

### `#set_properties`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L30)*

Optional: $set for identify

---

### `#timestamp`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L19)*

ISO8601 timestamp

---

### `#type`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L9)*

Message type (capture, identify, alias, etc.)

---

### `#uuid`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L40)*

Optional UUID for capture events

---

