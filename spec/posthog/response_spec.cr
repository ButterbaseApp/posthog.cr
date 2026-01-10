require "../spec_helper"

describe PostHog::Response do
  describe "#success?" do
    it "returns true for 2xx status codes" do
      PostHog::Response.new(200).success?.should be_true
      PostHog::Response.new(201).success?.should be_true
      PostHog::Response.new(204).success?.should be_true
      PostHog::Response.new(299).success?.should be_true
    end

    it "returns false for non-2xx status codes" do
      PostHog::Response.new(199).success?.should be_false
      PostHog::Response.new(300).success?.should be_false
      PostHog::Response.new(400).success?.should be_false
      PostHog::Response.new(500).success?.should be_false
      PostHog::Response.new(-1).success?.should be_false
    end
  end

  describe "#should_retry?" do
    it "returns true for 5xx server errors" do
      PostHog::Response.new(500).should_retry?.should be_true
      PostHog::Response.new(502).should_retry?.should be_true
      PostHog::Response.new(503).should_retry?.should be_true
      PostHog::Response.new(504).should_retry?.should be_true
      PostHog::Response.new(599).should_retry?.should be_true
    end

    it "returns true for 429 rate limit" do
      PostHog::Response.new(429).should_retry?.should be_true
    end

    it "returns true for network errors (-1)" do
      PostHog::Response.new(-1).should_retry?.should be_true
    end

    it "returns false for 4xx client errors (except 429)" do
      PostHog::Response.new(400).should_retry?.should be_false
      PostHog::Response.new(401).should_retry?.should be_false
      PostHog::Response.new(403).should_retry?.should be_false
      PostHog::Response.new(404).should_retry?.should be_false
      PostHog::Response.new(422).should_retry?.should be_false
    end

    it "returns false for 2xx success" do
      PostHog::Response.new(200).should_retry?.should be_false
      PostHog::Response.new(201).should_retry?.should be_false
    end
  end

  describe "#rate_limited?" do
    it "returns true for 429" do
      PostHog::Response.new(429).rate_limited?.should be_true
    end

    it "returns false for other status codes" do
      PostHog::Response.new(200).rate_limited?.should be_false
      PostHog::Response.new(500).rate_limited?.should be_false
      PostHog::Response.new(-1).rate_limited?.should be_false
    end
  end

  describe "#client_error?" do
    it "returns true for 4xx (except 429)" do
      PostHog::Response.new(400).client_error?.should be_true
      PostHog::Response.new(401).client_error?.should be_true
      PostHog::Response.new(403).client_error?.should be_true
      PostHog::Response.new(404).client_error?.should be_true
      PostHog::Response.new(499).client_error?.should be_true
    end

    it "returns false for 429" do
      PostHog::Response.new(429).client_error?.should be_false
    end

    it "returns false for non-4xx" do
      PostHog::Response.new(200).client_error?.should be_false
      PostHog::Response.new(500).client_error?.should be_false
    end
  end

  describe "#server_error?" do
    it "returns true for 5xx" do
      PostHog::Response.new(500).server_error?.should be_true
      PostHog::Response.new(503).server_error?.should be_true
      PostHog::Response.new(599).server_error?.should be_true
    end

    it "returns false for non-5xx" do
      PostHog::Response.new(200).server_error?.should be_false
      PostHog::Response.new(429).server_error?.should be_false
      PostHog::Response.new(-1).server_error?.should be_false
    end
  end

  describe "#network_error?" do
    it "returns true for -1" do
      PostHog::Response.new(-1).network_error?.should be_true
    end

    it "returns false for HTTP status codes" do
      PostHog::Response.new(200).network_error?.should be_false
      PostHog::Response.new(500).network_error?.should be_false
    end
  end

  describe "#error_message" do
    it "returns custom error if set" do
      response = PostHog::Response.new(500, error: "Custom error message")
      response.error_message.should eq "Custom error message"
    end

    it "returns appropriate message for status codes" do
      PostHog::Response.new(200).error_message.should eq "Success"
      PostHog::Response.new(400).error_message.should eq "Bad Request"
      PostHog::Response.new(401).error_message.should contain "Unauthorized"
      PostHog::Response.new(403).error_message.should eq "Forbidden"
      PostHog::Response.new(404).error_message.should eq "Not Found"
      PostHog::Response.new(429).error_message.should eq "Rate Limited"
      PostHog::Response.new(500).error_message.should contain "Server Error"
      PostHog::Response.new(-1).error_message.should eq "Network Error"
    end
  end

  describe "#retry_after" do
    it "stores retry-after value" do
      response = PostHog::Response.new(429, retry_after: 30.seconds)
      response.retry_after.should eq 30.seconds
    end

    it "is nil by default" do
      response = PostHog::Response.new(429)
      response.retry_after.should be_nil
    end
  end

  describe ".success" do
    it "creates a 200 response" do
      response = PostHog::Response.success
      response.status.should eq 200
      response.success?.should be_true
    end

    it "accepts custom body" do
      response = PostHog::Response.success(body: "{\"ok\": true}")
      response.body.should eq "{\"ok\": true}"
    end
  end

  describe ".network_error" do
    it "creates a -1 response with error message" do
      response = PostHog::Response.network_error("Connection refused")
      response.status.should eq(-1)
      response.error.should eq "Connection refused"
      response.should_retry?.should be_true
    end
  end

  describe ".timeout_error" do
    it "creates a timeout response" do
      response = PostHog::Response.timeout_error
      response.status.should eq(-1)
      response.error.should eq "Request timeout"
      response.should_retry?.should be_true
    end
  end
end

# Test backward compatibility alias
describe PostHog::TransportResponse do
  it "is an alias for Response" do
    response = PostHog::TransportResponse.new(200)
    response.should be_a(PostHog::Response)
  end
end
