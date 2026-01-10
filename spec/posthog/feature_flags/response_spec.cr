require "../../spec_helper"

describe PostHog::FeatureFlags::DecideResponse do
  describe ".from_json" do
    it "parses v2 format with flags object" do
      json = <<-JSON
      {
        "flags": {
          "bool-flag": {
            "key": "bool-flag",
            "enabled": true,
            "reason": {
              "code": "condition_match",
              "condition_index": 0,
              "description": "Matched condition set 1"
            },
            "metadata": {
              "id": 1,
              "version": 5,
              "payload": "{\\"color\\": \\"red\\"}"
            }
          },
          "variant-flag": {
            "key": "variant-flag",
            "enabled": true,
            "variant": "test-variant",
            "reason": {
              "code": "condition_match",
              "description": "Matched"
            },
            "metadata": {
              "id": 2,
              "version": 10
            }
          },
          "disabled-flag": {
            "key": "disabled-flag",
            "enabled": false,
            "reason": {
              "code": "no_condition_match"
            }
          }
        },
        "errorsWhileComputingFlags": false,
        "requestId": "req-123"
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.empty?.should be_false
      response.errors_while_computing_flags.should be_false
      response.request_id.should eq("req-123")
      response.quota_limited?.should be_false

      # Check bool flag
      response.flag_enabled?("bool-flag").should eq(true)
      response.get_flag("bool-flag").should eq(true)

      # Check variant flag
      response.flag_enabled?("variant-flag").should eq(true)
      response.get_flag("variant-flag").should eq("test-variant")

      # Check disabled flag
      response.flag_enabled?("disabled-flag").should eq(false)
      response.get_flag("disabled-flag").should eq(false)

      # Check flag objects
      bool_flag = response.get_flag_object("bool-flag")
      bool_flag.should_not be_nil
      bool_flag.try(&.enabled?).should eq(true)
      bool_flag.try(&.reason).try(&.code).should eq("condition_match")
      bool_flag.try(&.metadata).try(&.id).should eq(1)
      bool_flag.try(&.metadata).try(&.version).should eq(5)

      # Check payload parsing
      payload = response.get_payload("bool-flag")
      payload.should_not be_nil
      payload.try(&.["color"]?.try(&.as_s)).should eq("red")
    end

    it "parses legacy v3/v4 format with featureFlags" do
      json = <<-JSON
      {
        "featureFlags": {
          "flag-1": true,
          "flag-2": "variant-a",
          "flag-3": false
        },
        "featureFlagPayloads": {
          "flag-1": {"key": "value"},
          "flag-2": 100
        },
        "errorsWhileComputingFlags": false
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.flag_enabled?("flag-1").should eq(true)
      response.get_flag("flag-1").should eq(true)

      response.flag_enabled?("flag-2").should eq(true)
      response.get_flag("flag-2").should eq("variant-a")

      response.flag_enabled?("flag-3").should eq(false)
      response.get_flag("flag-3").should eq(false)

      # Check payloads
      response.get_payload("flag-1").try(&.["key"]?.try(&.as_s)).should eq("value")
      response.get_payload("flag-2").try(&.as_i?).should eq(100)
    end

    it "handles quota limited response with bool" do
      json = <<-JSON
      {
        "flags": {},
        "errorsWhileComputingFlags": false,
        "quotaLimited": true
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.empty?.should be_true
      response.quota_limited?.should be_true
    end

    it "handles quota limited response with array" do
      json = <<-JSON
      {
        "flags": {},
        "errorsWhileComputingFlags": false,
        "quotaLimited": ["feature_flags"]
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.quota_limited?.should be_true
      response.quota_limited.should contain("feature_flags")
    end

    it "handles errors while computing flags" do
      json = <<-JSON
      {
        "flags": {
          "flag-1": {"key": "flag-1", "enabled": true}
        },
        "errorsWhileComputingFlags": true
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.errors_while_computing_flags.should be_true
    end

    it "parses evaluated_at timestamp" do
      json = <<-JSON
      {
        "flags": {},
        "evaluatedAt": 1704067200
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.evaluated_at.should eq(1704067200)
    end

    it "returns nil for missing flags" do
      json = <<-JSON
      {
        "flags": {"existing": {"key": "existing", "enabled": true}}
      }
      JSON

      response = PostHog::FeatureFlags::DecideResponse.from_json(json)

      response.get_flag("missing").should be_nil
      response.flag_enabled?("missing").should be_nil
      response.get_payload("missing").should be_nil
    end
  end

  describe ".empty" do
    it "creates an empty response" do
      response = PostHog::FeatureFlags::DecideResponse.empty

      response.empty?.should be_true
      response.quota_limited?.should be_false
    end

    it "creates a quota limited empty response" do
      response = PostHog::FeatureFlags::DecideResponse.empty(quota_limited: true)

      response.empty?.should be_true
      response.quota_limited?.should be_true
    end
  end
end

describe PostHog::FeatureFlags::Flag do
  describe "#value" do
    it "returns bool for boolean flags" do
      flag = PostHog::FeatureFlags::Flag.new("test", enabled: true)
      flag.value.should eq(true)

      flag2 = PostHog::FeatureFlags::Flag.new("test", enabled: false)
      flag2.value.should eq(false)
    end

    it "returns variant string for multivariate flags" do
      flag = PostHog::FeatureFlags::Flag.new("test", enabled: true, variant: "control")
      flag.value.should eq("control")
    end
  end

  describe "#enabled?" do
    it "returns true when enabled" do
      flag = PostHog::FeatureFlags::Flag.new("test", enabled: true)
      flag.enabled?.should be_true
    end

    it "returns false when disabled" do
      flag = PostHog::FeatureFlags::Flag.new("test", enabled: false)
      flag.enabled?.should be_false
    end

    it "returns true for variant flags" do
      flag = PostHog::FeatureFlags::Flag.new("test", enabled: true, variant: "test")
      flag.enabled?.should be_true
    end
  end
end

describe PostHog::FeatureFlags::FlagReason do
  it "parses from JSON::Any" do
    data = JSON.parse(%({"code": "condition_match", "condition_index": 0, "description": "Matched"}))
    reason = PostHog::FeatureFlags::FlagReason.from_json_any(data)

    reason.should_not be_nil
    reason.try(&.code).should eq("condition_match")
    reason.try(&.condition_index).should eq(0)
    reason.try(&.description).should eq("Matched")
  end

  it "returns nil for nil input" do
    PostHog::FeatureFlags::FlagReason.from_json_any(nil).should be_nil
  end
end

describe PostHog::FeatureFlags::FlagMetadata do
  it "parses from JSON::Any with JSON-encoded payload" do
    data = JSON.parse(%({"id": 123, "version": 5, "payload": "{\\"key\\": \\"value\\"}"}))
    metadata = PostHog::FeatureFlags::FlagMetadata.from_json_any(data)

    metadata.should_not be_nil
    metadata.try(&.id).should eq(123)
    metadata.try(&.version).should eq(5)
    metadata.try(&.payload).try(&.["key"]?.try(&.as_s)).should eq("value")
  end

  it "handles non-string payload" do
    data = JSON.parse(%({"id": 1, "payload": {"direct": true}}))
    metadata = PostHog::FeatureFlags::FlagMetadata.from_json_any(data)

    metadata.try(&.payload).try(&.["direct"]?.try(&.as_bool)).should be_true
  end
end

describe PostHog::FeatureFlags::DecideRequest do
  it "serializes to JSON with all fields" do
    request = PostHog::FeatureFlags::DecideRequest.new(
      api_key: "test_key",
      distinct_id: "user_123",
      groups: {"company" => "acme"},
      person_properties: {"email" => JSON::Any.new("test@example.com")},
      group_properties: {
        "company" => {"tier" => JSON::Any.new("enterprise")},
      },
      geoip_disable: true
    )

    json = request.to_json
    parsed = JSON.parse(json)

    parsed["api_key"].as_s.should eq("test_key")
    parsed["distinct_id"].as_s.should eq("user_123")
    parsed["groups"]["company"].as_s.should eq("acme")
    parsed["person_properties"]["email"].as_s.should eq("test@example.com")
    parsed["group_properties"]["company"]["tier"].as_s.should eq("enterprise")
    parsed["geoip_disable"].as_bool.should be_true
  end

  it "omits nil fields" do
    request = PostHog::FeatureFlags::DecideRequest.new(
      api_key: "test_key",
      distinct_id: "user_123"
    )

    json = request.to_json
    parsed = JSON.parse(json)

    parsed["api_key"]?.should_not be_nil
    parsed["distinct_id"]?.should_not be_nil
    parsed["groups"]?.should be_nil
    parsed["person_properties"]?.should be_nil
    parsed["geoip_disable"]?.should be_nil
  end
end
