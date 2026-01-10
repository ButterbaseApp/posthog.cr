# BatchAddResult

`enum`

*Defined in [src/posthog/message.cr:63](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L63)*

Result of attempting to add a message to a batch

## Constants

### `Added`

```crystal
Added = 0
```

Message was added successfully

### `BatchFull`

```crystal
BatchFull = 1
```

Batch is full (by count or byte size), message not added

### `MessageTooLarge`

```crystal
MessageTooLarge = 2
```

Individual message exceeds max message size

## Instance Methods

### `#added?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L65)*

Returns `true` if this enum value equals `Added`

---

### `#batch_full?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L67)*

Returns `true` if this enum value equals `BatchFull`

---

### `#message_too_large?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L69)*

Returns `true` if this enum value equals `MessageTooLarge`

---

