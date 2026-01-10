# Worker

`class`

*Defined in [src/posthog/worker.cr:6](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L6)*

Background fiber worker that consumes messages from the queue
and sends them to PostHog in batches

## Constants

### `Log`

```crystal
Log = ::Log.for(self)
```

## Constructors

### `.new(config : Config, transport : Transport, message_channel : Channel(Message), control_channel : Channel(Control), on_message_processed : Proc(Nil) | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L20)*

---

## Instance Methods

### `#requesting?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L40)*

Check if the worker is currently processing a request

---

### `#running?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L45)*

Check if the worker is running

---

### `#start`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/worker.cr#L30)*

Start the worker fiber

---

## Nested Types

- [`Control`](posthog-worker-control.md) - <p>Control message types for the worker</p>

