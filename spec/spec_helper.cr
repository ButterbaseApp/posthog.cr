require "spec"
require "../src/posthog"

# Test helpers

# Create a simple mock transport for testing
class MockTransport < PostHog::Transport
  getter requests : Array(Tuple(String, PostHog::MessageBatch))
  property response : PostHog::TransportResponse

  def initialize
    super(host: "https://test.posthog.com")
    @requests = [] of Tuple(String, PostHog::MessageBatch)
    @response = PostHog::TransportResponse.new(200)
  end

  def send(api_key : String, batch : PostHog::MessageBatch) : PostHog::TransportResponse
    # Clone messages since batch may be cleared
    @requests << {api_key, batch}
    @response
  end

  def clear : Nil
    @requests.clear
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
