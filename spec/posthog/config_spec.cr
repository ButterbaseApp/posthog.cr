require "../spec_helper"

describe PostHog::Config do
  describe "#initialize" do
    it "creates config with required api_key" do
      config = PostHog::Config.new(api_key: "test_key")
      config.api_key.should eq "test_key"
    end

    it "raises ArgumentError for empty api_key" do
      expect_raises(ArgumentError, "API key is required") do
        PostHog::Config.new(api_key: "")
      end
    end

    it "uses default host" do
      config = PostHog::Config.new(api_key: "test")
      config.host.should eq PostHog::Defaults::HOST
    end

    it "allows custom host" do
      config = PostHog::Config.new(api_key: "test", host: "https://eu.posthog.com")
      config.host.should eq "https://eu.posthog.com"
    end

    it "uses default max_queue_size" do
      config = PostHog::Config.new(api_key: "test")
      config.max_queue_size.should eq PostHog::Defaults::MAX_QUEUE_SIZE
    end

    it "uses default batch_size" do
      config = PostHog::Config.new(api_key: "test")
      config.batch_size.should eq PostHog::Defaults::BATCH_SIZE
    end

    it "defaults async to true" do
      config = PostHog::Config.new(api_key: "test")
      config.async.should be_true
    end

    it "defaults skip_ssl_verification to false" do
      config = PostHog::Config.new(api_key: "test")
      config.skip_ssl_verification.should be_false
    end

    it "accepts on_error callback" do
      callback = ->(status : Int32, error : String) { nil }
      config = PostHog::Config.new(api_key: "test", on_error: callback)
      config.on_error.should_not be_nil
    end

    it "accepts before_send callback" do
      callback : PostHog::Config::BeforeSendProc = ->(event : Hash(String, JSON::Any)) { event.as(Hash(String, JSON::Any)?) }
      config = PostHog::Config.new(api_key: "test", before_send: callback)
      config.before_send.should_not be_nil
    end
  end

  describe "#normalized_host" do
    it "removes trailing slash" do
      config = PostHog::Config.new(api_key: "test", host: "https://posthog.com/")
      config.normalized_host.should eq "https://posthog.com"
    end

    it "keeps host without trailing slash unchanged" do
      config = PostHog::Config.new(api_key: "test", host: "https://posthog.com")
      config.normalized_host.should eq "https://posthog.com"
    end
  end
end

describe PostHog::Defaults do
  it "has correct HOST" do
    PostHog::Defaults::HOST.should eq "https://us.i.posthog.com"
  end

  it "has correct MAX_QUEUE_SIZE" do
    PostHog::Defaults::MAX_QUEUE_SIZE.should eq 10_000
  end

  it "has correct BATCH_SIZE" do
    PostHog::Defaults::BATCH_SIZE.should eq 100
  end

  it "has correct MAX_MESSAGE_BYTES" do
    PostHog::Defaults::MAX_MESSAGE_BYTES.should eq 32_768
  end

  it "has correct MAX_BATCH_BYTES" do
    PostHog::Defaults::MAX_BATCH_BYTES.should eq 512_000
  end
end
