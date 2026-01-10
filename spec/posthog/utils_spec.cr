require "../spec_helper"

describe PostHog::Utils do
  describe ".generate_uuid" do
    it "generates a valid UUID v4 format" do
      uuid = PostHog::Utils.generate_uuid
      uuid.should match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end

    it "generates unique UUIDs" do
      uuid1 = PostHog::Utils.generate_uuid
      uuid2 = PostHog::Utils.generate_uuid
      uuid1.should_not eq uuid2
    end
  end

  describe ".iso8601" do
    it "converts time to ISO8601 format with milliseconds" do
      time = Time.utc(2024, 1, 15, 10, 30, 45, nanosecond: 123_000_000)
      result = PostHog::Utils.iso8601(time)
      result.should eq "2024-01-15T10:30:45.123Z"
    end

    it "converts local time to UTC" do
      # Create a time and convert it
      time = Time.utc(2024, 6, 15, 14, 0, 0)
      result = PostHog::Utils.iso8601(time)
      result.should contain("T14:00:00")
      result.should end_with("Z")
    end
  end

  describe ".valid_uuid?" do
    it "returns true for valid UUID" do
      PostHog::Utils.valid_uuid?("550e8400-e29b-41d4-a716-446655440000").should be_true
    end

    it "returns true for uppercase UUID" do
      PostHog::Utils.valid_uuid?("550E8400-E29B-41D4-A716-446655440000").should be_true
    end

    it "returns false for invalid UUID" do
      PostHog::Utils.valid_uuid?("not-a-uuid").should be_false
    end

    it "returns false for nil" do
      PostHog::Utils.valid_uuid?(nil).should be_false
    end

    it "returns false for empty string" do
      PostHog::Utils.valid_uuid?("").should be_false
    end

    it "returns false for UUID without dashes" do
      PostHog::Utils.valid_uuid?("550e8400e29b41d4a716446655440000").should be_false
    end
  end

  describe ".sha1_hash" do
    it "returns a value between 0 and 1" do
      result = PostHog::Utils.sha1_hash("test_flag", "user_123")
      result.should be >= 0.0
      result.should be < 1.0
    end

    it "returns consistent values for same inputs" do
      result1 = PostHog::Utils.sha1_hash("flag", "user")
      result2 = PostHog::Utils.sha1_hash("flag", "user")
      result1.should eq result2
    end

    it "returns different values for different inputs" do
      result1 = PostHog::Utils.sha1_hash("flag", "user1")
      result2 = PostHog::Utils.sha1_hash("flag", "user2")
      result1.should_not eq result2
    end

    it "incorporates salt into hash" do
      result1 = PostHog::Utils.sha1_hash("flag", "user", "salt1")
      result2 = PostHog::Utils.sha1_hash("flag", "user", "salt2")
      result1.should_not eq result2
    end
  end
end
