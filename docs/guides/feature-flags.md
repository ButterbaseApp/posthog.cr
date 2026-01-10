# Feature Flags Guide

Feature flags (also known as feature toggles or experiments) allow you to safely deploy new features, conduct A/B tests, and manage feature access without redeploying your application.

The PostHog Crystal SDK provides a robust implementation of feature flags, supporting both **Remote Evaluation** (server-side) and **Local Evaluation** (client-side) for maximum flexibility and performance.

---

## Remote vs. Local Evaluation

| Feature | Remote Evaluation | Local Evaluation |
| :--- | :--- | :--- |
| **Latency** | Network request per check (or batch) | Near-zero (in-memory) |
| **Setup** | Simple (uses Project API Key) | Advanced (requires Personal API Key) |
| **Complexity** | Low | Higher (polls for definitions) |
| **Accuracy** | 100% (server-side logic) | High (supports most property operators) |
| **Consistency** | Perfect | High (consistent hashing) |

---

## Configuration

### Basic Configuration (Remote Only)

To use remote evaluation only, you just need your **Project API Key**.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_your_project_api_key",
  host: "https://us.i.posthog.com"
)
```

### Advanced Configuration (Local Evaluation)

Local evaluation is highly recommended for performance-critical applications. It downloads flag definitions once and evaluates them in-memory. To enable it, you must provide a **Personal API Key**.

```crystal
posthog = PostHog::Client.new(
  api_key: "phc_your_project_api_key",
  personal_api_key: "phx_your_personal_api_key", # Enables local evaluation
  feature_flags_polling_interval: 30.seconds      # Optional: default is 30s
)
```

> **Warning**: Keep your `personal_api_key` secret. It should only be used in server-side environments.

---

## Basic Usage

### Check if a flag is enabled

Use `feature_enabled?` for boolean flags or to check if a user is in *any* variant of a multivariate flag.

```crystal
if posthog.feature_enabled?("new-beta-feature", "user_123")
  # Show the new feature
end
```

### Get a flag value (Multivariate)

For multivariate flags (experiments), use `feature_flag` to get the specific variant string.

```crystal
variant = posthog.feature_flag("pricing-experiment", "user_123")

case variant
when "control"
  # Show original price
when "test-v1"
  # Show discounted price
when "test-v2"
  # Show premium price
else
  # Flag is disabled
end
```

### Get all flags for a user

If you need to pass all flags to your frontend or another service, use `all_flags`.

```crystal
flags = posthog.all_flags("user_123")
# Returns Hash(String, Bool | String | Nil)
```

---

## Advanced Flag Features

### Group-based Flags

PostHog supports targeting flags to groups (e.g., organizations, companies, projects).

```crystal
enabled = posthog.feature_enabled?(
  "organization-feature",
  "user_123",
  groups: {"organization" => "acme_inc"}
)
```

### Targeting with Properties

You can provide person or group properties during evaluation to match specific flag conditions immediately (especially useful for local evaluation).

```crystal
enabled = posthog.feature_enabled?(
  "premium-only-feature",
  "user_123",
  person_properties: {"plan" => JSON::Any.new("premium")},
  group_properties: {
    "organization" => {"industry" => JSON::Any.new("technology")}
  }
)
```

### Flag Payloads

Feature flag payloads allow you to attach arbitrary JSON data to a flag or a specific variant.

```crystal
payload = posthog.feature_flag_payload("banner-config", "user_123")

if config = payload
  banner_color = config["color"]?.try(&.as_s) || "blue"
  banner_text = config["text"]?.try(&.as_s) || "Welcome!"
end
```

To get both flags and payloads efficiently:

```crystal
result = posthog.all_flags_and_payloads("user_123")
flags = result[:flags]
payloads = result[:payloads]
```

---

## Integration with Event Capture

### Including flags in events

You can automatically include the state of all active feature flags when capturing an event. This is useful for analyzing how flags affect user behavior.

```crystal
posthog.capture(
  distinct_id: "user_123",
  event: "button_clicked",
  send_feature_flags: true # Automatically injects active flag states
)
```

### The `$feature_flag_called` event

By default, the SDK emits a `$feature_flag_called` event whenever a flag is evaluated. This allows PostHog to track which flags were used and by whom.

- These events are **deduplicated** automatically per `distinct_id` and flag value.
- They include metadata like `locally_evaluated` and `reason`.

---

## Best Practices & Performance

### 1. Use Local Evaluation for High Volume
Remote evaluation adds network latency to every check. For high-traffic applications, always use `personal_api_key` to enable local evaluation.

### 2. Selective Local Evaluation
If you want to ensure no network requests are made for a specific flag check, use the `only_evaluate_locally` option.

```crystal
# This will return nil if the flag cannot be evaluated locally (e.g. no definitions yet)
# and will NOT fall back to a network request.
enabled = posthog.feature_enabled?(
  "my-flag", 
  "user_123", 
  only_evaluate_locally: true
)
```

### 3. Cache/Pass Flags to Frontend
If you are building a web application, evaluate flags on the server and pass them to your frontend (e.g., via a window object) to avoid double-fetching.

### 4. Handle `nil` results
Methods like `feature_enabled?` can return `nil` if the flag doesn't exist or there was a connection error. Always have a sensible default in your application logic.

### 5. Use Group Analytics
If your app is B2B, set up groups in PostHog and use group-based flags to ensure consistent experiences across all users in an organization.

### 6. Manual Refresh
If you need to ensure the local cache is up-to-date (e.g., after updating a flag in the PostHog UI), you can force a reload:

```crystal
posthog.reload_feature_flags
```

---

## Important Considerations for Local Evaluation

While powerful, local evaluation has some limitations that trigger an automatic fallback to remote evaluation (if `only_evaluate_locally` is false):

1. **Static Cohorts**: Evaluation of static cohorts requires server-side data and cannot be done locally.
2. **Experience Continuity**: Flags with "Experience Continuity" enabled must be evaluated on the server to ensure the same variant is served across different devices.
3. **Circular Dependencies**: If flag A depends on flag B and flag B depends on flag A, local evaluation will fail.
4. **Missing Properties**: If a flag depends on a property that wasn't provided in the `person_properties` or `group_properties` arguments, and it's not in the cached definitions, it may fall back to the server.

---

## Local Evaluation Property Operators

The local evaluator supports the following operators for property matching:

- `exact` / `is_not`
- `icontains` / `not_icontains`
- `regex` / `not_regex`
- `gt` (greater than), `gte` (greater than or equal)
- `lt` (less than), `lte` (less than or equal)
- `is_set` / `is_not_set`
- `is_date_before` / `is_date_after` (supports relative dates like `-6h`, `1d`, `1w`)
