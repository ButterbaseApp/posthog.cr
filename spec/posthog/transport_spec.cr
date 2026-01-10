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

  describe "#shutdown" do
    it "can be called multiple times" do
      transport = PostHog::Transport.new(host: "https://app.posthog.com")
      transport.shutdown
      transport.shutdown # Should not raise
    end
  end
end

describe PostHog::TransportResponse do
  describe "#success?" do
    it "returns true for 2xx status" do
      PostHog::TransportResponse.new(200).success?.should be_true
      PostHog::TransportResponse.new(201).success?.should be_true
      PostHog::TransportResponse.new(204).success?.should be_true
    end

    it "returns false for non-2xx status" do
      PostHog::TransportResponse.new(400).success?.should be_false
      PostHog::TransportResponse.new(500).success?.should be_false
      PostHog::TransportResponse.new(-1).success?.should be_false
    end
  end

  describe "#should_retry?" do
    it "returns true for 5xx status" do
      PostHog::TransportResponse.new(500).should_retry?.should be_true
      PostHog::TransportResponse.new(502).should_retry?.should be_true
      PostHog::TransportResponse.new(503).should_retry?.should be_true
    end

    it "returns true for 429 rate limit" do
      PostHog::TransportResponse.new(429).should_retry?.should be_true
    end

    it "returns false for 4xx (except 429)" do
      PostHog::TransportResponse.new(400).should_retry?.should be_false
      PostHog::TransportResponse.new(401).should_retry?.should be_false
      PostHog::TransportResponse.new(403).should_retry?.should be_false
      PostHog::TransportResponse.new(404).should_retry?.should be_false
    end

    it "returns false for 2xx" do
      PostHog::TransportResponse.new(200).should_retry?.should be_false
    end
  end
end
