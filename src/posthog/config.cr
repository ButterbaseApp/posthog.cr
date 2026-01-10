module PostHog
  # Default configuration values
  module Defaults
    # API host defaults
    HOST = "https://us.i.posthog.com"

    # Queue settings
    MAX_QUEUE_SIZE = 10_000
    BATCH_SIZE     =    100

    # Request settings
    REQUEST_TIMEOUT = 10.seconds
    MAX_RETRIES     = 10

    # Message limits
    MAX_MESSAGE_BYTES = 32_768  # 32KB per message
    MAX_BATCH_BYTES   = 512_000 # 500KB per batch

    # Backoff policy
    BACKOFF_MIN        = 100.milliseconds
    BACKOFF_MAX        = 10.seconds
    BACKOFF_MULTIPLIER = 1.5

    # Feature flags
    FEATURE_FLAGS_POLLING_INTERVAL = 30.seconds
    FEATURE_FLAG_REQUEST_TIMEOUT   = 3.seconds
  end

  # Client configuration
  class Config
    # Required: Your PostHog project API key
    property api_key : String

    # API host (PostHog Cloud US, EU, or self-hosted)
    property host : String

    # Personal API key for local feature flag evaluation
    property personal_api_key : String?

    # Maximum number of messages to queue before dropping
    property max_queue_size : Int32

    # Number of messages to send in each batch
    property batch_size : Int32

    # Request timeout for API calls
    property request_timeout : Time::Span

    # Whether to skip SSL verification (development only)
    property skip_ssl_verification : Bool

    # Whether to use async mode (background fiber) or sync mode
    property async : Bool

    # Test mode - when true, messages are queued but not sent
    property test_mode : Bool

    # Feature flags polling interval
    property feature_flags_polling_interval : Time::Span

    # Feature flag request timeout
    property feature_flag_request_timeout : Time::Span

    # Error callback - called when an error occurs
    property on_error : Proc(Int32, String, Nil)?

    # Before send hook - can modify or drop events
    # Return the modified event, or nil to drop it
    alias BeforeSendProc = Proc(Hash(String, JSON::Any), Hash(String, JSON::Any)?)
    property before_send : BeforeSendProc?

    def initialize(
      @api_key : String,
      @host : String = Defaults::HOST,
      @personal_api_key : String? = nil,
      @max_queue_size : Int32 = Defaults::MAX_QUEUE_SIZE,
      @batch_size : Int32 = Defaults::BATCH_SIZE,
      @request_timeout : Time::Span = Defaults::REQUEST_TIMEOUT,
      @skip_ssl_verification : Bool = false,
      @async : Bool = true,
      @test_mode : Bool = false,
      @feature_flags_polling_interval : Time::Span = Defaults::FEATURE_FLAGS_POLLING_INTERVAL,
      @feature_flag_request_timeout : Time::Span = Defaults::FEATURE_FLAG_REQUEST_TIMEOUT,
      @on_error : Proc(Int32, String, Nil)? = nil,
      @before_send : BeforeSendProc? = nil
    )
      raise ArgumentError.new("API key is required") if @api_key.empty?
    end

    # Normalize host URL (remove trailing slash)
    def normalized_host : String
      @host.chomp("/")
    end
  end
end
