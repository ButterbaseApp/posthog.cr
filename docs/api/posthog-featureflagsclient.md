# FeatureFlagsClient

`class`

*Defined in [src/posthog/feature_flags.cr:40](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L40)*

Feature flags client with support for both local and remote evaluation.

By default, uses remote evaluation via the /flags API. When a personal_api_key
is provided, enables local evaluation for low-latency decisions.

Local evaluation:
- Polls /api/feature_flag/local_evaluation/ for flag definitions
- Evaluates flags locally using cached definitions
- Falls back to remote evaluation when local evaluation fails

Example:
```
# Remote evaluation only
client = PostHog::Client.new(api_key: "phc_xxx")

# Local evaluation enabled
client = PostHog::Client.new(
  api_key: "phc_xxx",
  personal_api_key: "phx_xxx"  # Enables local evaluation
)

# Check if a flag is enabled
if client.feature_enabled?("new-feature", "user_123")
  # Show new feature
end

# Get a multivariate flag value
variant = client.feature_flag("experiment", "user_123")
```

## Constants

### `Log`

```crystal
Log = ::Log.for(self)
```

## Constructors

### `.new(config : Config)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L159)*

---

## Instance Methods

### `#all_flags(distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil, only_evaluate_locally : Bool = false) : Hash(String, FeatureFlags::FlagValue)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L276)*

Get all feature flags for a user

Returns a hash of flag keys to their values (true, false, or variant string)

---

### `#all_flags_and_payloads(distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil, only_evaluate_locally : Bool = false) : NamedTuple(flags: Hash(String, FeatureFlags::FlagValue), payloads: Hash(String, JSON::Any))`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L347)*

Get all flags and their payloads for a user

Returns a NamedTuple with:
- `flags` - Hash of flag keys to values
- `payloads` - Hash of flag keys to payloads

---

### `#feature_enabled?(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil, only_evaluate_locally : Bool = false) : Bool | Nil`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L218)*

Check if a feature flag is enabled for a user

Returns:
- `true` if the flag is enabled
- `false` if the flag is disabled
- `nil` if the flag is not found or there was an error

Options:
- `groups` - Group memberships for group-based flags
- `person_properties` - Properties for person-based targeting
- `group_properties` - Properties for group-based targeting
- `only_evaluate_locally` - Skip server fallback (returns nil if local fails)

---

### `#feature_flag(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil, only_evaluate_locally : Bool = false) : FeatureFlags::FlagValue`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L253)*

Get the value of a feature flag

Returns:
- `true` or `false` for boolean flags
- A variant string for multivariate flags
- `nil` if the flag is not found or there was an error

---

### `#feature_flag_payload(key : String, distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil, only_evaluate_locally : Bool = false) : JSON::Any | Nil`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L322)*

Get the payload for a specific feature flag

Feature flag payloads allow you to attach JSON data to flag variants.
Returns `nil` if the flag has no payload or doesn't exist.

---

### `#flush_flag_call_events`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L437)*

Get pending $feature_flag_called events and clear the cache

Returns an array of event data to be captured

---

### `#get_feature_variants_for_capture(distinct_id : String, groups : Hash(String, String) | Nil = nil, person_properties : Properties | Nil = nil, group_properties : GroupProperties | Nil = nil) : Hash(String, JSON::Any) | Nil`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L409)*

Get flags to inject into a capture event when send_feature_flags is true

Returns the feature variants hash to pass to FieldParser.parse_for_capture

---

### `#has_pending_flag_calls?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L462)*

Check if there are pending flag call events

---

### `#local_evaluation_enabled?`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L194)*

Check if local evaluation is enabled.

---

### `#reload_feature_flags`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L202)*

Manually reload feature flag definitions.

Forces an immediate poll of the local evaluation endpoint.
Only works if local evaluation is enabled.

---

### `#shutdown`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L469)*

Shutdown and cleanup

---

### `#start_poller`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L184)*

Start the local evaluation poller.

Only has effect if personal_api_key was provided during initialization.
Called automatically by Client when needed.

---

### `#stop_poller`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L189)*

Stop the local evaluation poller.

---

## Nested Types

- [`FeatureFlagCalledEvent`](posthog-featureflagsclient-featureflagcalledevent.md) - <p>Event data for $feature_flag_called</p>

