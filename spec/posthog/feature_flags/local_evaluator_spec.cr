require "../../spec_helper"

describe PostHog::FeatureFlags::LocalEvaluator do
  describe "#set_flag_definitions" do
    it "stores flag definitions" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"    => JSON::Any.new("test-flag"),
          "active" => JSON::Any.new(true),
        }),
      ]

      evaluator.set_flag_definitions(flags)

      evaluator.has_flags?.should be_true
      evaluator.flag_keys.should eq(["test-flag"])
    end
  end

  describe "#evaluate" do
    it "returns true for simple enabled flag" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("test-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties"         => JSON::Any.new([] of JSON::Any),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      result = evaluator.evaluate("test-flag", "user-123")

      result.locally_evaluated?.should be_true
      result.value.should eq(true)
    end

    it "returns false for inactive flag" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"    => JSON::Any.new("inactive-flag"),
          "active" => JSON::Any.new(false),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      result = evaluator.evaluate("inactive-flag", "user-123")

      result.locally_evaluated?.should be_true
      result.value.should eq(false)
    end

    it "returns inconclusive for unknown flag" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new
      evaluator.set_flag_definitions([] of JSON::Any)

      result = evaluator.evaluate("unknown-flag", "user-123")

      result.locally_evaluated?.should be_false
      result.value.should be_nil
    end

    it "evaluates property conditions" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("email-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties" => JSON::Any.new([
                  JSON::Any.new({
                    "key"      => JSON::Any.new("email"),
                    "operator" => JSON::Any.new("icontains"),
                    "value"    => JSON::Any.new("@example.com"),
                  }),
                ]),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)

      # Matching email
      result = evaluator.evaluate(
        "email-flag",
        "user-123",
        person_properties: {"email" => JSON::Any.new("user@example.com")}
      )
      result.value.should eq(true)

      # Non-matching email
      result = evaluator.evaluate(
        "email-flag",
        "user-456",
        person_properties: {"email" => JSON::Any.new("user@other.com")}
      )
      result.value.should eq(false)
    end

    it "respects rollout percentage" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("rollout-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties"         => JSON::Any.new([] of JSON::Any),
                "rollout_percentage" => JSON::Any.new(50),
              }),
            ]),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)

      # Count how many users are in the rollout
      enabled_count = 0
      100.times do |i|
        result = evaluator.evaluate("rollout-flag", "user-#{i}")
        enabled_count += 1 if result.value == true
      end

      # Should be roughly 50%, allow some variance
      enabled_count.should be >= 30
      enabled_count.should be <= 70
    end

    it "returns variant for multivariate flag" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("variant-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties"         => JSON::Any.new([] of JSON::Any),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
            "multivariate" => JSON::Any.new({
              "variants" => JSON::Any.new([
                JSON::Any.new({"key" => JSON::Any.new("control"), "rollout_percentage" => JSON::Any.new(50)}),
                JSON::Any.new({"key" => JSON::Any.new("test"), "rollout_percentage" => JSON::Any.new(50)}),
              ]),
            }),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      result = evaluator.evaluate("variant-flag", "user-123")

      result.locally_evaluated?.should be_true
      ["control", "test"].should contain(result.value)
    end

    it "evaluates multiple conditions (OR between groups)" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("multi-condition-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              # First condition: email contains @admin
              JSON::Any.new({
                "properties" => JSON::Any.new([
                  JSON::Any.new({
                    "key"      => JSON::Any.new("email"),
                    "operator" => JSON::Any.new("icontains"),
                    "value"    => JSON::Any.new("@admin"),
                  }),
                ]),
                "rollout_percentage" => JSON::Any.new(100),
              }),
              # Second condition: plan is premium
              JSON::Any.new({
                "properties" => JSON::Any.new([
                  JSON::Any.new({
                    "key"      => JSON::Any.new("plan"),
                    "operator" => JSON::Any.new("exact"),
                    "value"    => JSON::Any.new("premium"),
                  }),
                ]),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)

      # Matches first condition
      result = evaluator.evaluate(
        "multi-condition-flag",
        "user-1",
        person_properties: {
          "email" => JSON::Any.new("user@admin.com"),
          "plan"  => JSON::Any.new("free"),
        }
      )
      result.value.should eq(true)

      # Matches second condition
      result = evaluator.evaluate(
        "multi-condition-flag",
        "user-2",
        person_properties: {
          "email" => JSON::Any.new("user@example.com"),
          "plan"  => JSON::Any.new("premium"),
        }
      )
      result.value.should eq(true)

      # Matches neither
      result = evaluator.evaluate(
        "multi-condition-flag",
        "user-3",
        person_properties: {
          "email" => JSON::Any.new("user@example.com"),
          "plan"  => JSON::Any.new("free"),
        }
      )
      result.value.should eq(false)
    end

    it "includes flag metadata in result" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "id"      => JSON::Any.new(123_i64),
          "key"     => JSON::Any.new("meta-flag"),
          "active"  => JSON::Any.new(true),
          "version" => JSON::Any.new(5_i64),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties"         => JSON::Any.new([] of JSON::Any),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      result = evaluator.evaluate("meta-flag", "user-123")

      result.flag_id.should eq(123)
      result.flag_version.should eq(5)
    end

    it "returns payload when flag has payloads" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("payload-flag"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({
                "properties"         => JSON::Any.new([] of JSON::Any),
                "rollout_percentage" => JSON::Any.new(100),
              }),
            ]),
            "payloads" => JSON::Any.new({
              "true" => JSON::Any.new("{\"color\": \"red\"}"),
            }),
          }),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      result = evaluator.evaluate("payload-flag", "user-123")

      result.payload.should_not be_nil
      result.payload.try(&.["color"]?.try(&.as_s)).should eq("red")
    end
  end

  describe "#evaluate_all" do
    it "evaluates all flags" do
      evaluator = PostHog::FeatureFlags::LocalEvaluator.new

      flags = [
        JSON::Any.new({
          "key"     => JSON::Any.new("flag-1"),
          "active"  => JSON::Any.new(true),
          "filters" => JSON::Any.new({
            "groups" => JSON::Any.new([
              JSON::Any.new({"properties" => JSON::Any.new([] of JSON::Any), "rollout_percentage" => JSON::Any.new(100)}),
            ]),
          }),
        }),
        JSON::Any.new({
          "key"    => JSON::Any.new("flag-2"),
          "active" => JSON::Any.new(false),
        }),
      ]

      evaluator.set_flag_definitions(flags)
      results = evaluator.evaluate_all("user-123")

      results.size.should eq(2)
      results["flag-1"].value.should eq(true)
      results["flag-2"].value.should eq(false)
    end
  end
end
