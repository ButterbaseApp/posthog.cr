require "spec"
require "../src/posthog"

# Test helpers

# Create a simple mock transport for testing
class MockTransport < PostHog::Transport
  getter requests : Array(Tuple(String, PostHog::MessageBatch))
  property response : PostHog::Response
  property responses : Array(PostHog::Response)?
  @response_index : Int32 = 0

  def initialize
    super(host: "https://test.posthog.com")
    @requests = [] of Tuple(String, PostHog::MessageBatch)
    @response = PostHog::Response.new(200)
    @responses = nil
    @response_index = 0
  end

  def send(api_key : String, batch : PostHog::MessageBatch) : PostHog::Response
    # Clone messages since batch may be cleared
    @requests << {api_key, batch}

    # If multiple responses configured, cycle through them
    if resps = @responses
      resp = resps[@response_index]? || resps.last
      @response_index += 1
      resp
    else
      @response
    end
  end

  # Override send_once to use the same mock behavior
  def send_once(api_key : String, batch : PostHog::MessageBatch) : PostHog::Response
    send(api_key, batch)
  end

  def clear : Nil
    @requests.clear
    @response_index = 0
  end

  # Configure a sequence of responses for retry testing
  def set_responses(responses : Array(PostHog::Response)) : Nil
    @responses = responses
    @response_index = 0
  end
end

# Helper to create a test client with test mode enabled
def create_test_client(
  api_key : String = "test_api_key",
  async : Bool = false,
  test_mode : Bool = true,
  on_error : Proc(Int32, String, Nil)? = nil,
  before_send : PostHog::Config::BeforeSendProc? = nil
) : PostHog::Client
  PostHog::Client.new(
    api_key: api_key,
    host: "https://test.posthog.com",
    async: async,
    test_mode: test_mode,
    on_error: on_error,
    before_send: before_send
  )
end

# Helper to create properties hash
def props(**values) : Hash(String, JSON::Any)
  hash = Hash(String, JSON::Any).new
  values.each do |key, value|
    hash[key.to_s] = case value
                     when String
                       JSON::Any.new(value)
                     when Int32, Int64
                       JSON::Any.new(value.to_i64)
                     when Float64
                       JSON::Any.new(value)
                     when Bool
                       JSON::Any.new(value)
                     when Nil
                       JSON::Any.new(nil)
                     else
                       JSON::Any.new(value.to_s)
                     end
  end
  hash
end
