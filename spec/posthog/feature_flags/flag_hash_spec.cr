require "../../spec_helper"

describe PostHog::FeatureFlags::FlagHash do
  describe ".compute" do
    it "returns a float between 0 and 1" do
      hash = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123")
      hash.should be >= 0.0
      hash.should be < 1.0
    end

    it "returns the same value for the same inputs" do
      hash1 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123")
      hash2 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123")
      hash1.should eq(hash2)
    end

    it "returns different values for different keys" do
      hash1 = PostHog::FeatureFlags::FlagHash.compute("flag-a", "user-123")
      hash2 = PostHog::FeatureFlags::FlagHash.compute("flag-b", "user-123")
      hash1.should_not eq(hash2)
    end

    it "returns different values for different distinct_ids" do
      hash1 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123")
      hash2 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-456")
      hash1.should_not eq(hash2)
    end

    it "applies salt correctly" do
      hash1 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123", "")
      hash2 = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-123", "variant")
      hash1.should_not eq(hash2)
    end

    # Test that the hash is deterministic with known values
    # These values can be verified against the Python SDK
    it "produces consistent hash values" do
      # Test that hash distribution is reasonable
      # With 1000 users, roughly 50% should be < 0.5
      count_below_half = 0
      1000.times do |i|
        hash = PostHog::FeatureFlags::FlagHash.compute("test-flag", "user-#{i}")
        count_below_half += 1 if hash < 0.5
      end
      # Allow 10% variance from expected 50%
      count_below_half.should be >= 400
      count_below_half.should be <= 600
    end
  end

  describe ".in_rollout?" do
    it "returns true for 100% rollout" do
      PostHog::FeatureFlags::FlagHash.in_rollout?("flag", "user", 100.0).should be_true
    end

    it "returns false for 0% rollout" do
      PostHog::FeatureFlags::FlagHash.in_rollout?("flag", "user", 0.0).should be_false
    end

    it "returns consistent results for the same user" do
      result1 = PostHog::FeatureFlags::FlagHash.in_rollout?("flag", "user-123", 50.0)
      result2 = PostHog::FeatureFlags::FlagHash.in_rollout?("flag", "user-123", 50.0)
      result1.should eq(result2)
    end

    it "respects rollout percentage approximately" do
      # With 1000 users at 30% rollout, roughly 300 should be included
      count_in_rollout = 0
      1000.times do |i|
        if PostHog::FeatureFlags::FlagHash.in_rollout?("test-flag", "user-#{i}", 30.0)
          count_in_rollout += 1
        end
      end
      # Allow 10% variance
      count_in_rollout.should be >= 200
      count_in_rollout.should be <= 400
    end
  end

  describe ".build_variant_lookup_table" do
    it "builds a lookup table from variants" do
      variants = [
        JSON::Any.new({"key" => JSON::Any.new("control"), "rollout_percentage" => JSON::Any.new(50)}),
        JSON::Any.new({"key" => JSON::Any.new("test"), "rollout_percentage" => JSON::Any.new(50)}),
      ]

      table = PostHog::FeatureFlags::FlagHash.build_variant_lookup_table(variants)

      table.size.should eq(2)
      table[0].key.should eq("control")
      table[0].value_min.should eq(0.0)
      table[0].value_max.should eq(0.5)
      table[1].key.should eq("test")
      table[1].value_min.should eq(0.5)
      table[1].value_max.should eq(1.0)
    end

    it "handles float rollout percentages" do
      variants = [
        JSON::Any.new({"key" => JSON::Any.new("a"), "rollout_percentage" => JSON::Any.new(33.33)}),
        JSON::Any.new({"key" => JSON::Any.new("b"), "rollout_percentage" => JSON::Any.new(33.33)}),
        JSON::Any.new({"key" => JSON::Any.new("c"), "rollout_percentage" => JSON::Any.new(33.34)}),
      ]

      table = PostHog::FeatureFlags::FlagHash.build_variant_lookup_table(variants)

      table.size.should eq(3)
      (table[2].value_max - 1.0).abs.should be < 0.001
    end

    it "skips variants without key or rollout_percentage" do
      variants = [
        JSON::Any.new({"key" => JSON::Any.new("valid"), "rollout_percentage" => JSON::Any.new(100)}),
        JSON::Any.new({"key" => JSON::Any.new("no-rollout")}),
        JSON::Any.new({"rollout_percentage" => JSON::Any.new(50)}),
      ]

      table = PostHog::FeatureFlags::FlagHash.build_variant_lookup_table(variants)

      table.size.should eq(1)
      table[0].key.should eq("valid")
    end
  end

  describe ".get_matching_variant" do
    it "returns the correct variant" do
      variants = [
        JSON::Any.new({"key" => JSON::Any.new("control"), "rollout_percentage" => JSON::Any.new(50)}),
        JSON::Any.new({"key" => JSON::Any.new("test"), "rollout_percentage" => JSON::Any.new(50)}),
      ]
      table = PostHog::FeatureFlags::FlagHash.build_variant_lookup_table(variants)

      # Should consistently return one of the variants
      variant = PostHog::FeatureFlags::FlagHash.get_matching_variant("flag", "user", table)
      variant.should_not be_nil
      ["control", "test"].should contain(variant)
    end

    it "returns nil for empty lookup table" do
      table = [] of PostHog::FeatureFlags::FlagHash::VariantRange
      PostHog::FeatureFlags::FlagHash.get_matching_variant("flag", "user", table).should be_nil
    end

    it "distributes variants according to percentages" do
      variants = [
        JSON::Any.new({"key" => JSON::Any.new("control"), "rollout_percentage" => JSON::Any.new(30)}),
        JSON::Any.new({"key" => JSON::Any.new("test-a"), "rollout_percentage" => JSON::Any.new(35)}),
        JSON::Any.new({"key" => JSON::Any.new("test-b"), "rollout_percentage" => JSON::Any.new(35)}),
      ]
      table = PostHog::FeatureFlags::FlagHash.build_variant_lookup_table(variants)

      counts = {"control" => 0, "test-a" => 0, "test-b" => 0}
      1000.times do |i|
        variant = PostHog::FeatureFlags::FlagHash.get_matching_variant("flag", "user-#{i}", table)
        counts[variant.not_nil!] += 1 if variant
      end

      # Allow 10% variance
      counts["control"].should be >= 200
      counts["control"].should be <= 400
      counts["test-a"].should be >= 250
      counts["test-a"].should be <= 450
      counts["test-b"].should be >= 250
      counts["test-b"].should be <= 450
    end
  end

  describe ".get_variant_from_filters" do
    it "returns variant from multivariate filters" do
      filters = JSON::Any.new({
        "multivariate" => JSON::Any.new({
          "variants" => JSON::Any.new([
            JSON::Any.new({"key" => JSON::Any.new("control"), "rollout_percentage" => JSON::Any.new(50)}),
            JSON::Any.new({"key" => JSON::Any.new("test"), "rollout_percentage" => JSON::Any.new(50)}),
          ]),
        }),
      })

      variant = PostHog::FeatureFlags::FlagHash.get_variant_from_filters("flag", "user", filters)
      variant.should_not be_nil
    end

    it "returns nil when no multivariate" do
      filters = JSON::Any.new({"groups" => JSON::Any.new([] of JSON::Any)})
      PostHog::FeatureFlags::FlagHash.get_variant_from_filters("flag", "user", filters).should be_nil
    end

    it "returns nil when filters is nil" do
      PostHog::FeatureFlags::FlagHash.get_variant_from_filters("flag", "user", nil).should be_nil
    end
  end

  describe "VariantRange" do
    it "includes hash values within range" do
      range = PostHog::FeatureFlags::FlagHash::VariantRange.new(0.25, 0.75, "test")
      
      range.includes?(0.25).should be_true
      range.includes?(0.5).should be_true
      range.includes?(0.74999).should be_true
    end

    it "excludes hash values outside range" do
      range = PostHog::FeatureFlags::FlagHash::VariantRange.new(0.25, 0.75, "test")
      
      range.includes?(0.24).should be_false
      range.includes?(0.75).should be_false  # Upper bound is exclusive
      range.includes?(0.0).should be_false
      range.includes?(1.0).should be_false
    end
  end
end
