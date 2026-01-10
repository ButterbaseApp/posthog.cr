require "http/client"
require "json"
require "log"

module PostHog
  # HTTP transport for sending batches to PostHog
  #
  # Handles HTTP communication with the PostHog API including:
  # - Connection management
  # - Request headers
  # - Retry logic with exponential backoff
  # - SSL configuration
  # - Timeout handling
  #
  # Example:
  # ```
  # transport = Transport.new(
  #   host: "https://us.i.posthog.com",
  #   timeout: 10.seconds,
  #   max_retries: 3
  # )
  #
  # response = transport.send(api_key, batch)
  # transport.shutdown
  # ```
  class Transport
    Log = ::Log.for(self)

    @client : HTTP::Client?
    @backoff : BackoffPolicy

    def initialize(
      @host : String,
      @timeout : Time::Span = Defaults::REQUEST_TIMEOUT,
      @skip_ssl_verification : Bool = false,
      @max_retries : Int32 = Defaults::MAX_RETRIES
    )
      @client = nil
      @backoff = BackoffPolicy.new(max_retries: @max_retries)
    end

    # Send a batch of messages to PostHog with automatic retry
    #
    # Returns a Response indicating success or failure.
    # Automatically retries on 5xx and 429 responses with exponential backoff.
    def send(api_key : String, batch : MessageBatch) : Response
      return Response.success if batch.empty?

      payload = batch.to_json_payload(api_key)
      headers = build_headers

      @backoff.reset
      attempt = 0

      loop do
        response = send_request(headers, payload)

        # Success - return immediately
        return response if response.success?

        # Check if we should retry
        if response.should_retry? && @backoff.should_retry?(attempt)
          attempt += 1
          wait_time = calculate_wait_time(response)
          Log.debug { "Retrying request (attempt #{attempt}/#{@max_retries}), waiting #{wait_time.total_seconds}s" }
          sleep(wait_time)
        else
          # Non-retryable error or max retries exceeded
          if attempt > 0
            Log.warn { "Request failed after #{attempt} retries: status=#{response.status}" }
          end
          return response
        end
      end
    end

    # Send a single request without retry logic
    # Useful for testing or when you want to handle retries yourself
    def send_once(api_key : String, batch : MessageBatch) : Response
      return Response.success if batch.empty?

      payload = batch.to_json_payload(api_key)
      headers = build_headers
      send_request(headers, payload)
    end

    # Shutdown the transport and close connections
    def shutdown : Nil
      @client.try(&.close)
      @client = nil
    end

    private def send_request(headers : HTTP::Headers, payload : String) : Response
      begin
        client = get_client
        response = client.post("/batch", headers: headers, body: payload)

        retry_after = parse_retry_after(response.headers["Retry-After"]?)

        Response.new(
          status: response.status_code,
          body: response.body,
          retry_after: retry_after
        )
      rescue ex : Socket::Error | IO::Error | OpenSSL::SSL::Error
        Log.error { "Transport error: #{ex.message}" }
        Response.network_error(ex.message || "Connection error")
      rescue ex : IO::TimeoutError
        Log.error { "Transport timeout: #{ex.message}" }
        Response.timeout_error
      end
    end

    private def calculate_wait_time(response : Response) : Time::Span
      # Respect Retry-After header if present
      if retry_after = response.retry_after
        return retry_after
      end

      # Otherwise use backoff policy
      @backoff.next_interval
    end

    private def parse_retry_after(value : String?) : Time::Span?
      return nil if value.nil? || value.empty?

      # Retry-After can be either seconds or an HTTP date
      # We only handle seconds for simplicity
      if seconds = value.to_i64?
        Time::Span.new(seconds: seconds)
      else
        nil
      end
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
        "Accept"       => "application/json",
      }
    end
  end

  # Legacy alias for backward compatibility
  # @deprecated Use `Response` instead
  alias TransportResponse = Response
end
