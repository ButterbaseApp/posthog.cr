# MessageBatch

`class`

*Defined in [src/posthog/message.cr:94](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L94)*

A batch of messages ready to be sent

Enforces PostHog API limits:
- Max 32KB per message
- Max 500KB per batch
- Max 100 messages per batch (configurable)

Example:
```
batch = MessageBatch.new
case batch.add(message)
when .added?
  puts "Message queued"
when .batch_full?
  # Send current batch, then retry
  transport.send(api_key, batch)
  batch.clear
  batch.add(message)
when .message_too_large?
  puts "Message dropped: exceeds 32KB limit"
end
```

## Constructors

### `.new(max_size : Int32 = Defaults::BATCH_SIZE, max_bytes : Int32 = Defaults::MAX_BATCH_BYTES)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L100)*

---

## Instance Methods

### `#<<(message : Message) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L109)*

Try to add a message to the batch
Returns true if added, false if batch is full or message too large

@deprecated Use `add` instead for more detailed result information

---

### `#add(message : Message) : BatchAddResult`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L116)*

Add a message to the batch with detailed result

Returns BatchAddResult indicating success or reason for failure.

---

### `#clear`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L165)*

Clear the batch

---

### `#empty?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L145)*

Check if the batch is empty

---

### `#full?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L140)*

Check if the batch is full

---

### `#payload_size(api_key : String) : Int32`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L179)*

Total payload size in bytes (including api_key wrapper)

---

### `#remaining_bytes`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L160)*

Remaining capacity in bytes (approximate)

---

### `#remaining_capacity`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L155)*

Remaining capacity in messages (by count)

---

### `#size`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L150)*

Number of messages in the batch

---

### `#to_json_payload(api_key : String) : String`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/message.cr#L171)*

Convert to JSON payload for API

---

