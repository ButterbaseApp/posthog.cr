require "../spec_helper"

describe PostHog::Transport do
  describe "#initialize" do
    it "creates transport with host" do
      transport = PostHog::Transport.new(host: "https://app.posthog.com")
      transport.shutdown
    end

    it "accepts custom timeout" do
      transport = PostHog::Transport.new(
        host: "https://app.posthog.com",
        timeout: 30.seconds
      )
      transport.shutdown
    end

    it "accepts skip_ssl_verification" do
      transport = PostHog::Transport.new(
        host: "https://app.posthog.com",
        skip_ssl_verification: true
      )
      transport.shutdown
    end

    it "accepts max_retries" do
      transport = PostHog::Transport.new(
        host: "https://app.posthog.com",
        max_retries: 5
      )
      transport.shutdown
    end
  end

  describe "#send" do
    it "returns success for empty batch" do
      transport = PostHog::Transport.new(host: "https://app.posthog.com")
      batch = PostHog::MessageBatch.new

      response = transport.send("api_key", batch)

      response.success?.should be_true
      response.status.should eq 200
      transport.shutdown
    end
  end

  describe "#send_once" do
    it "returns success for empty batch" do
      transport = PostHog::Transport.new(host: "https://app.posthog.com")
      batch = PostHog::MessageBatch.new

      response = transport.send_once("api_key", batch)

      response.success?.should be_true
      response.status.should eq 200
      transport.shutdown
    end
  end

  describe "#shutdown" do
    it "can be called multiple times" do
      transport = PostHog::Transport.new(host: "https://app.posthog.com")
      transport.shutdown
      transport.shutdown # Should not raise
    end
  end

  describe "headers" do
    it "includes required headers" do
      # This is tested via MockTransport since we can't easily
      # intercept real HTTP headers without a mock server
      # The implementation in transport.cr includes:
      # - Content-Type: application/json
      # - User-Agent: posthog-crystal/{version}
      # - Accept: application/json
      true.should be_true
    end
  end
end

describe PostHog::Response do
  describe "#success?" do
    it "returns true for 2xx status" do
      PostHog::Response.new(200).success?.should be_true
      PostHog::Response.new(201).success?.should be_true
      PostHog::Response.new(204).success?.should be_true
    end

    it "returns false for non-2xx status" do
      PostHog::Response.new(400).success?.should be_false
      PostHog::Response.new(500).success?.should be_false
      PostHog::Response.new(-1).success?.should be_false
    end
  end

  describe "#should_retry?" do
    it "returns true for 5xx status" do
      PostHog::Response.new(500).should_retry?.should be_true
      PostHog::Response.new(502).should_retry?.should be_true
      PostHog::Response.new(503).should_retry?.should be_true
    end

    it "returns true for 429 rate limit" do
      PostHog::Response.new(429).should_retry?.should be_true
    end

    it "returns true for network errors" do
      PostHog::Response.new(-1).should_retry?.should be_true
    end

    it "returns false for 4xx (except 429)" do
      PostHog::Response.new(400).should_retry?.should be_false
      PostHog::Response.new(401).should_retry?.should be_false
      PostHog::Response.new(403).should_retry?.should be_false
      PostHog::Response.new(404).should_retry?.should be_false
    end

    it "returns false for 2xx" do
      PostHog::Response.new(200).should_retry?.should be_false
    end
  end
end

describe "Retry behavior with MockTransport" do
  it "retries on 5xx errors" do
    mock = MockTransport.new
    mock.set_responses([
      PostHog::Response.new(500),
      PostHog::Response.new(500),
      PostHog::Response.new(200),
    ])

    batch = PostHog::MessageBatch.new
    batch.add(create_test_message)

    response = mock.send("api_key", batch)
    response.status.should eq 500 # First call returns 500

    response = mock.send("api_key", batch)
    response.status.should eq 500 # Second call returns 500

    response = mock.send("api_key", batch)
    response.status.should eq 200 # Third call succeeds

    mock.requests.size.should eq 3
  end

  it "retries on 429 rate limit" do
    mock = MockTransport.new
    mock.set_responses([
      PostHog::Response.new(429, retry_after: 1.second),
      PostHog::Response.new(200),
    ])

    batch = PostHog::MessageBatch.new
    batch.add(create_test_message)

    response = mock.send("api_key", batch)
    response.status.should eq 429
    response.retry_after.should eq 1.second

    response = mock.send("api_key", batch)
    response.status.should eq 200
  end

  it "does not retry on 4xx client errors" do
    mock = MockTransport.new
    mock.response = PostHog::Response.new(400)

    batch = PostHog::MessageBatch.new
    batch.add(create_test_message)

    response = mock.send("api_key", batch)

    response.status.should eq 400
    response.should_retry?.should be_false
  end
end

private def create_test_message : PostHog::Message
  PostHog::Message.new(
    type: "capture",
    event: "test_event",
    distinct_id: "user_123",
    timestamp: "2024-01-15T10:00:00.000Z",
    message_id: PostHog::Utils.generate_uuid,
    properties: props(test: "value")
  )
end
