require "http/client"
require "json"
require "log"

module PostHog
  # Response from the transport layer
  struct TransportResponse
    getter status : Int32
    getter body : String
    getter error : String?

    def initialize(@status : Int32, @body : String = "", @error : String? = nil)
    end

    def success? : Bool
      @status >= 200 && @status < 300
    end

    def should_retry? : Bool
      # Retry on 5xx server errors and 429 rate limit
      @status >= 500 || @status == 429
    end
  end

  # HTTP transport for sending batches to PostHog
  class Transport
    Log = ::Log.for(self)

    @client : HTTP::Client?

    def initialize(
      @host : String,
      @timeout : Time::Span = Defaults::REQUEST_TIMEOUT,
      @skip_ssl_verification : Bool = false
    )
      @client = nil
    end

    # Send a batch of messages to PostHog
    def send(api_key : String, batch : MessageBatch) : TransportResponse
      return TransportResponse.new(200) if batch.empty?

      payload = batch.to_json_payload(api_key)
      headers = build_headers

      begin
        client = get_client
        response = client.post("/batch", headers: headers, body: payload)

        TransportResponse.new(
          status: response.status_code,
          body: response.body
        )
      rescue ex : Socket::Error | IO::Error | OpenSSL::SSL::Error
        Log.error { "Transport error: #{ex.message}" }
        TransportResponse.new(
          status: -1,
          error: ex.message
        )
      rescue ex : IO::TimeoutError
        Log.error { "Transport timeout: #{ex.message}" }
        TransportResponse.new(
          status: -1,
          error: "Request timeout"
        )
      end
    end

    # Shutdown the transport and close connections
    def shutdown : Nil
      @client.try(&.close)
      @client = nil
    end

    private def get_client : HTTP::Client
      @client ||= begin
        uri = URI.parse(@host)

        tls_context = if @skip_ssl_verification && uri.scheme == "https"
                        ctx = OpenSSL::SSL::Context::Client.new
                        ctx.verify_mode = OpenSSL::SSL::VerifyMode::NONE
                        ctx
                      elsif uri.scheme == "https"
                        OpenSSL::SSL::Context::Client.new
                      else
                        nil
                      end

        client = HTTP::Client.new(uri, tls: tls_context)
        client.read_timeout = @timeout
        client.connect_timeout = @timeout
        client
      end
    end

    private def build_headers : HTTP::Headers
      HTTP::Headers{
        "Content-Type" => "application/json",
        "User-Agent"   => "posthog-crystal/#{VERSION}",
      }
    end
  end
end
