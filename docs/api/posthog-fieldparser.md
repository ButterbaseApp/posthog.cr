# FieldParser

`module`

*Defined in [src/posthog/field_parser.cr:5](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L5)*

Parses and validates input fields, producing normalized Message objects

## Instance Methods

### `#parse_for_alias(distinct_id : String, alias_id : String, timestamp : Time = Time.utc) : Message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L89)*

Parse fields for an alias event

---

### `#parse_for_capture(distinct_id : String, event : String, properties : Properties = Properties.new, groups : Hash(String, String) | Nil = nil, timestamp : Time = Time.utc, uuid : String | Nil = nil, feature_variants : Hash(String, JSON::Any) | Nil = nil) : Message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L15)*

Parse fields for a capture event

---

### `#parse_for_exception(distinct_id : String, properties : Properties = Properties.new, timestamp : Time = Time.utc) : Message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L141)*

Parse fields for an exception event

---

### `#parse_for_group_identify(group_type : String, group_key : String, properties : Properties = Properties.new, distinct_id : String | Nil = nil, timestamp : Time = Time.utc) : Message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L112)*

Parse fields for a group identify event

---

### `#parse_for_identify(distinct_id : String, properties : Properties = Properties.new, timestamp : Time = Time.utc) : Message`

*[View source](https://github.com/watzon/posthog.cr/blob/main/src/posthog/field_parser.cr#L68)*

Parse fields for an identify event

---

## Nested Types

- [`Properties`](posthog-fieldparser-properties.md) - <p>Type alias for properties hash</p>

