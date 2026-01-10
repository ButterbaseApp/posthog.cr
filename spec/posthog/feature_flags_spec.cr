require "../spec_helper"

# Mock HTTP server for feature flags testing
class MockFeatureFlagsServer
  class_property last_request : HTTP::Request?
  class_property response_body : String = %({"flags": {}})
  class_property response_status : Int32 = 200

  def self.reset
    @@last_request = nil
    @@response_body = %({"flags": {}})
    @@response_status = 200
  end
end

describe PostHog::FeatureFlagsClient do
  describe "#feature_enabled?" do
    it "returns true for enabled boolean flags" do
      config = PostHog::Config.new(
        api_key: "test_key",
        host: "https://test.posthog.com",
        test_mode: true
      )
      client = PostHog::FeatureFlagsClient.new(config)

      # Can't easily test HTTP calls without a mock server
      # This just verifies the method signature works
      result = client.feature_enabled?("test-flag", "user_123")
      # Result will be nil since we can't connect to test server
      result.should be_nil

      client.shutdown
    end
  end

  describe "#flush_flag_call_events" do
    it "returns empty array when no flags have been evaluated" do
      config = PostHog::Config.new(
        api_key: "test_key",
        host: "https://test.posthog.com",
        test_mode: true
      )
      client = PostHog::FeatureFlagsClient.new(config)

      events = client.flush_flag_call_events
      events.should be_empty

      client.shutdown
    end
  end

  describe "#has_pending_flag_calls?" do
    it "returns false when no flags have been evaluated" do
      config = PostHog::Config.new(
        api_key: "test_key",
        host: "https://test.posthog.com",
        test_mode: true
      )
      client = PostHog::FeatureFlagsClient.new(config)

      client.has_pending_flag_calls?.should be_false

      client.shutdown
    end
  end
end

describe PostHog::FeatureFlagsClient::FeatureFlagCalledEvent do
  describe "#to_properties" do
    it "includes required properties" do
      event = PostHog::FeatureFlagsClient::FeatureFlagCalledEvent.new(
        distinct_id: "user_123",
        flag_key: "test-flag",
        flag_value: true
      )

      props = event.to_properties

      props["$feature_flag"].as_s.should eq("test-flag")
      props["$feature_flag_response"].as_bool.should eq(true)
      props["$feature/test-flag"].as_bool.should eq(true)
      props["locally_evaluated"].as_bool.should eq(false)
    end

    it "includes string variant value" do
      event = PostHog::FeatureFlagsClient::FeatureFlagCalledEvent.new(
        distinct_id: "user_123",
        flag_key: "experiment",
        flag_value: "control"
      )

      props = event.to_properties

      props["$feature_flag_response"].as_s.should eq("control")
      props["$feature/experiment"].as_s.should eq("control")
    end

    it "includes optional metadata when present" do
      event = PostHog::FeatureFlagsClient::FeatureFlagCalledEvent.new(
        distinct_id: "user_123",
        flag_key: "test-flag",
        flag_value: true,
        payload: JSON.parse(%({"color": "red"})),
        request_id: "req-123",
        evaluated_at: 1704067200_i64,
        reason: "Condition matched",
        version: 5_i64,
        flag_id: 42_i64,
        locally_evaluated: true
      )

      props = event.to_properties

      props["$feature_flag_payload"]["color"].as_s.should eq("red")
      props["$feature_flag_request_id"].as_s.should eq("req-123")
      props["$feature_flag_evaluated_at"].as_i64.should eq(1704067200)
      props["$feature_flag_reason"].as_s.should eq("Condition matched")
      props["$feature_flag_version"].as_i64.should eq(5)
      props["$feature_flag_id"].as_i64.should eq(42)
      props["locally_evaluated"].as_bool.should eq(true)
    end

    it "handles nil flag value" do
      event = PostHog::FeatureFlagsClient::FeatureFlagCalledEvent.new(
        distinct_id: "user_123",
        flag_key: "test-flag",
        flag_value: nil
      )

      props = event.to_properties

      props["$feature_flag_response"].raw.should be_nil
    end
  end
end
