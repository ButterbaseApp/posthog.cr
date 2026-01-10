# Client

`class`

*Defined in [src/posthog/client.cr:5](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L5)*

The main PostHog client for capturing events and managing feature flags

## Constants

### `Log`

```crystal
Log = ::Log.for(self)
```

## Constructors

### `.new(api_key : String, host : String = Defaults::HOST, personal_api_key : String | Nil = nil, max_queue_size : Int32 = Defaults::MAX_QUEUE_SIZE, batch_size : Int32 = Defaults::BATCH_SIZE, request_timeout : Time::Span = Defaults::REQUEST_TIMEOUT, skip_ssl_verification : Bool = false, async : Bool = true, test_mode : Bool = false, on_error : Proc(Int32, String, Nil) | Nil = nil, before_send : Config::BeforeSendProc | Nil = nil)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L20)*

---

## Instance Methods

### `#alias(distinct_id : String, alias_id : String, timestamp : Time = Time.utc) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L146)*

Create an alias between two user IDs

```
client.alias(distinct_id: "user_123", alias_id: "anon_456")
```

---

### `#all_flags(distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : Hash(String, Properties) | Nil = nil, only_evaluate_locally : Bool = false) : Hash(String, FeatureFlags::FlagValue)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L372)*

Get all feature flags for a user

Returns a hash of flag keys to their values (true, false, or variant string)

```
flags = client.all_flags("user_123")
flags.each do |key, value|
  puts "#{key}: #{value}"
end
```

---

### `#all_flags_and_payloads(distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : Hash(String, Properties) | Nil = nil, only_evaluate_locally : Bool = false) : NamedTuple(flags: Hash(String, FeatureFlags::FlagValue), payloads: Hash(String, JSON::Any))`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L428)*

Get all flags and their payloads for a user

Returns a NamedTuple with:
- `flags` - Hash of flag keys to values
- `payloads` - Hash of flag keys to payloads

```
result = client.all_flags_and_payloads("user_123")
result[:flags].each { |k, v| puts "Flag #{k}: #{v}" }
result[:payloads].each { |k, v| puts "Payload #{k}: #{v}" }
```

---

### `#capture(distinct_id : String, event : String, properties : Properties = Properties.new, groups : Hash(String, String) | Nil = nil, timestamp : Time = Time.utc, uuid : String | Nil = nil, send_feature_flags : Bool = false) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L79)*

Capture an event

```
client.capture(
  distinct_id: "user_123",
  event: "button_clicked",
  properties: {"color" => JSON::Any.new("blue")}
)
```

---

### `#capture_exception(exception : Exception, distinct_id : String | Nil = nil, properties : Properties = Properties.new, timestamp : Time = Time.utc, handled : Bool = true) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L205)*

Capture an exception with stack trace

```
begin
  risky_operation
rescue ex
  client.capture_exception(ex, distinct_id: "user_123")
end
```

If distinct_id is not provided, a UUID will be generated and
`$process_person_profile` will be set to `false`.

---

### `#capture_exception(message : String, distinct_id : String | Nil = nil, properties : Properties = Properties.new, timestamp : Time = Time.utc) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L245)*

Capture an exception from a string message (no backtrace)

```
client.capture_exception("Something went wrong", distinct_id: "user_123")
```

---

### `#feature_enabled?(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : Hash(String, Properties) | Nil = nil, only_evaluate_locally : Bool = false) : Bool | Nil`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L310)*

Check if a feature flag is enabled for a user

Returns:
- `true` if the flag is enabled
- `false` if the flag is disabled
- `nil` if the flag is not found or there was an error

```
if client.feature_enabled?("new-feature", "user_123")
  # Show new feature
end
```

---

### `#feature_flag(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : Hash(String, Properties) | Nil = nil, only_evaluate_locally : Bool = false) : FeatureFlags::FlagValue`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L344)*

Get the value of a feature flag

Returns:
- `true` or `false` for boolean flags
- A variant string for multivariate flags
- `nil` if the flag is not found or there was an error

```
variant = client.feature_flag("experiment", "user_123")
case variant
when "control"
  # Control group
when "test"
  # Test group
end
```

---

### `#feature_flag_payload(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : Hash(String, Properties) | Nil = nil, only_evaluate_locally : Bool = false) : JSON::Any | Nil`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L399)*

Get the payload for a specific feature flag

Feature flag payloads allow you to attach JSON data to flag variants.
Returns `nil` if the flag has no payload or doesn't exist.

```
payload = client.feature_flag_payload("my-flag", "user_123")
if config = payload
  puts config["color"]?
end
```

---

### `#flush`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L448)*

Flush all pending messages synchronously
Blocks until the queue is empty

---

### `#group_identify(group_type : String, group_key : String, properties : Properties = Properties.new, distinct_id : String | Nil = nil, timestamp : Time = Time.utc) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L169)*

Identify a group with properties

```
client.group_identify(
  group_type: "company",
  group_key: "acme_inc",
  properties: {"name" => JSON::Any.new("Acme Inc")}
)
```

---

### `#identify(distinct_id : String, properties : Properties = Properties.new, timestamp : Time = Time.utc) : Bool`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L123)*

Identify a user with properties

```
client.identify(
  distinct_id: "user_123",
  properties: {"email" => JSON::Any.new("user@example.com")}
)
```

---

### `#local_evaluation_enabled?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L282)*

Check if local evaluation is enabled (personal_api_key was provided)

---

### `#queue_size`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L484)*

Get the current queue size

---

### `#reload_feature_flags`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L294)*

Manually reload feature flag definitions from the server.

Only works when local evaluation is enabled (personal_api_key provided).
Useful for forcing an immediate refresh after flag changes.

```
client.reload_feature_flags
```

---

### `#shutdown`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L462)*

Shutdown the client gracefully
Flushes pending messages and stops the worker

---

### `#shutdown?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/client.cr#L489)*

Check if the client has been shut down

---

## Nested Types

- [`Properties`](posthog-client-properties.md) - <p>Alias for properties hash type</p>

