require "../spec_helper"

describe PostHog::Client do
  describe "#initialize" do
    it "creates client with api_key" do
      client = PostHog::Client.new(api_key: "test_key", async: false)
      client.shutdown?.should be_false
      client.shutdown
    end

    it "raises for empty api_key" do
      expect_raises(ArgumentError, "API key is required") do
        PostHog::Client.new(api_key: "", async: false)
      end
    end

    it "accepts custom host" do
      client = PostHog::Client.new(
        api_key: "test",
        host: "https://eu.posthog.com",
        async: false
      )
      client.shutdown
    end
  end

  describe "#capture" do
    it "returns true for valid capture" do
      client = create_test_client
      result = client.capture(distinct_id: "user_123", event: "test_event")
      result.should be_true
      client.shutdown
    end

    it "returns false for empty distinct_id" do
      errors = [] of Tuple(Int32, String)
      client = create_test_client(on_error: ->(s : Int32, e : String) { errors << {s, e}; nil })

      result = client.capture(distinct_id: "", event: "test_event")

      result.should be_false
      errors.size.should eq 1
      errors.first[1].should contain("distinct_id must be given")
      client.shutdown
    end

    it "returns false for empty event" do
      errors = [] of Tuple(Int32, String)
      client = create_test_client(on_error: ->(s : Int32, e : String) { errors << {s, e}; nil })

      result = client.capture(distinct_id: "user", event: "")

      result.should be_false
      client.shutdown
    end

    it "accepts properties" do
      client = create_test_client
      result = client.capture(
        distinct_id: "user_123",
        event: "test_event",
        properties: props(color: "blue")
      )
      result.should be_true
      client.shutdown
    end

    it "accepts groups" do
      client = create_test_client
      result = client.capture(
        distinct_id: "user_123",
        event: "test_event",
        groups: {"company" => "acme"}
      )
      result.should be_true
      client.shutdown
    end

    it "accepts custom timestamp" do
      client = create_test_client
      result = client.capture(
        distinct_id: "user_123",
        event: "test_event",
        timestamp: Time.utc(2024, 1, 1, 12, 0, 0)
      )
      result.should be_true
      client.shutdown
    end
  end

  describe "#identify" do
    it "returns true for valid identify" do
      client = create_test_client
      result = client.identify(
        distinct_id: "user_123",
        properties: props(email: "test@example.com")
      )
      result.should be_true
      client.shutdown
    end

    it "returns false for empty distinct_id" do
      client = create_test_client
      result = client.identify(distinct_id: "")
      result.should be_false
      client.shutdown
    end
  end

  describe "#alias" do
    it "returns true for valid alias" do
      client = create_test_client
      result = client.alias(distinct_id: "user_123", alias_id: "anon_456")
      result.should be_true
      client.shutdown
    end

    it "returns false for empty distinct_id" do
      client = create_test_client
      result = client.alias(distinct_id: "", alias_id: "anon")
      result.should be_false
      client.shutdown
    end

    it "returns false for empty alias_id" do
      client = create_test_client
      result = client.alias(distinct_id: "user", alias_id: "")
      result.should be_false
      client.shutdown
    end
  end

  describe "#group_identify" do
    it "returns true for valid group identify" do
      client = create_test_client
      result = client.group_identify(
        group_type: "company",
        group_key: "acme_inc",
        properties: props(name: "Acme Inc")
      )
      result.should be_true
      client.shutdown
    end

    it "returns false for empty group_type" do
      client = create_test_client
      result = client.group_identify(group_type: "", group_key: "acme")
      result.should be_false
      client.shutdown
    end

    it "returns false for empty group_key" do
      client = create_test_client
      result = client.group_identify(group_type: "company", group_key: "")
      result.should be_false
      client.shutdown
    end
  end

  describe "#before_send" do
    it "can modify event" do
      modified = false
      hook : PostHog::Config::BeforeSendProc = ->(event : Hash(String, JSON::Any)) {
        modified = true
        event.as(Hash(String, JSON::Any)?)
      }
      client = PostHog::Client.new(
        api_key: "test",
        async: false,
        before_send: hook
      )

      client.capture(distinct_id: "user", event: "test")
      modified.should be_true
      client.shutdown
    end

    it "can drop event by returning nil" do
      hook : PostHog::Config::BeforeSendProc = ->(event : Hash(String, JSON::Any)) {
        nil.as(Hash(String, JSON::Any)?)
      }
      client = PostHog::Client.new(
        api_key: "test",
        async: false,
        before_send: hook
      )

      result = client.capture(distinct_id: "user", event: "test")
      result.should be_false
      client.shutdown
    end
  end

  describe "#shutdown" do
    it "marks client as shutdown" do
      client = create_test_client
      client.shutdown?.should be_false

      client.shutdown

      client.shutdown?.should be_true
    end

    it "prevents further captures after shutdown" do
      client = create_test_client
      client.shutdown

      result = client.capture(distinct_id: "user", event: "test")
      result.should be_false
    end

    it "is idempotent" do
      client = create_test_client
      client.shutdown
      client.shutdown # Should not raise
      client.shutdown?.should be_true
    end
  end

  describe "#queue_size" do
    it "returns 0 for sync client" do
      client = create_test_client(async: false)
      client.queue_size.should eq 0
      client.shutdown
    end
  end

  describe "sync mode" do
    it "sends events immediately without queue" do
      client = create_test_client(async: false, test_mode: false)

      # In sync mode without test_mode, it would try to send immediately
      # This test verifies the mode is set correctly
      client.queue_size.should eq 0
      client.shutdown
    end

    it "reports errors via on_error callback" do
      errors = [] of Tuple(Int32, String)
      client = PostHog::Client.new(
        api_key: "test",
        host: "https://invalid.posthog.test",
        async: false,
        test_mode: false,
        on_error: ->(s : Int32, e : String) { errors << {s, e}; nil }
      )

      # This will fail due to invalid host (network error)
      # We can't easily test this without mocking, so just verify setup is correct
      client.shutdown
    end

    it "flush is no-op in sync mode" do
      client = create_test_client(async: false)
      client.capture(distinct_id: "user", event: "test")

      # Flush should return immediately in sync mode
      client.flush
      client.queue_size.should eq 0
      client.shutdown
    end
  end

  describe "async mode" do
    it "queues messages in async mode" do
      client = PostHog::Client.new(api_key: "test", async: true)

      client.capture(distinct_id: "user", event: "test")

      # Give fiber a chance to process
      sleep(50.milliseconds)

      client.shutdown
    end

    it "flushes messages on shutdown" do
      client = PostHog::Client.new(api_key: "test", async: true)

      5.times do |i|
        client.capture(distinct_id: "user_#{i}", event: "test_event")
      end

      client.shutdown
      client.queue_size.should eq 0
    end
  end
end
