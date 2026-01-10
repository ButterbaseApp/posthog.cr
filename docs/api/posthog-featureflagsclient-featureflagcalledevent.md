# FeatureFlagCalledEvent

`struct`

*Defined in [src/posthog/feature_flags.cr:75](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L75)*

Event data for $feature_flag_called

## Constructors

### `.new(distinct_id : String, flag_key : String, flag_value : FeatureFlags::FlagValue, payload : JSON::Any | Nil = nil, request_id : String | Nil = nil, evaluated_at : Int64 | Nil = nil, reason : String | Nil = nil, version : Int64 | Nil = nil, flag_id : Int64 | Nil = nil, locally_evaluated : Bool = false)`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L87)*

---

## Instance Methods

### `#to_properties`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/feature_flags.cr#L102)*

Convert to properties hash for capture

---

