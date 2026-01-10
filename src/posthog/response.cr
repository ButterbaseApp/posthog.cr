module PostHog
  # Response from the transport layer
  #
  # Encapsulates HTTP response status, body, and error information.
  # Provides helpers for determining success and retry eligibility.
  #
  # Example:
  # ```
  # response = transport.send(api_key, batch)
  # if response.success?
  #   puts "Batch sent successfully"
  # elsif response.should_retry?
  #   puts "Temporary error, will retry"
  # else
  #   puts "Permanent error: #{response.error}"
  # end
  # ```
  struct Response
    # HTTP status code, or -1 for network/connection errors
    getter status : Int32

    # Response body from the server
    getter body : String

    # Error message for failed requests
    getter error : String?

    # Retry-After header value in seconds (for 429 responses)
    getter retry_after : Time::Span?

    def initialize(
      @status : Int32,
      @body : String = "",
      @error : String? = nil,
      @retry_after : Time::Span? = nil
    )
    end

    # Check if the request was successful (2xx status)
    def success? : Bool
      @status >= 200 && @status < 300
    end

    # Check if the request should be retried
    #
    # Retryable conditions:
    # - 5xx server errors
    # - 429 rate limit
    # - Network errors (status -1)
    def should_retry? : Bool
      @status >= 500 || @status == 429 || @status == -1
    end

    # Check if this is a rate limit response
    def rate_limited? : Bool
      @status == 429
    end

    # Check if this is a client error (4xx, excluding 429)
    def client_error? : Bool
      @status >= 400 && @status < 500 && @status != 429
    end

    # Check if this is a server error (5xx)
    def server_error? : Bool
      @status >= 500
    end

    # Check if this is a network/connection error
    def network_error? : Bool
      @status == -1
    end

    # Get a human-readable error message
    def error_message : String
      return @error.not_nil! if @error

      case @status
      when 200..299
        "Success"
      when 400
        "Bad Request"
      when 401
        "Unauthorized - check your API key"
      when 403
        "Forbidden"
      when 404
        "Not Found"
      when 429
        "Rate Limited"
      when 500..599
        "Server Error (#{@status})"
      when -1
        "Network Error"
      else
        "HTTP #{@status}"
      end
    end

    # Create a success response
    def self.success(body : String = "") : Response
      new(status: 200, body: body)
    end

    # Create a network error response
    def self.network_error(error : String) : Response
      new(status: -1, error: error)
    end

    # Create a timeout error response
    def self.timeout_error : Response
      new(status: -1, error: "Request timeout")
    end
  end
end
