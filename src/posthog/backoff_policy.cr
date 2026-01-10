module PostHog
  # Exponential backoff policy with jitter for retry logic
  #
  # Uses the decorrelated jitter algorithm to prevent thundering herd:
  # https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
  #
  # Example:
  # ```
  # policy = BackoffPolicy.new
  # attempt = 0
  # loop do
  #   break if attempt >= policy.max_retries
  #   response = make_request()
  #   break if response.success?
  #   sleep(policy.next_interval)
  #   attempt += 1
  # end
  # ```
  class BackoffPolicy
    getter min : Time::Span
    getter max : Time::Span
    getter multiplier : Float64
    getter max_retries : Int32

    @current : Time::Span

    def initialize(
      @min : Time::Span = Defaults::BACKOFF_MIN,
      @max : Time::Span = Defaults::BACKOFF_MAX,
      @multiplier : Float64 = Defaults::BACKOFF_MULTIPLIER,
      @max_retries : Int32 = Defaults::MAX_RETRIES
    )
      @current = @min
    end

    # Calculate the next backoff interval with jitter
    # Uses decorrelated jitter: sleep = min(max, random_between(min, sleep * multiplier))
    def next_interval : Time::Span
      # Calculate next value with jitter
      temp = @current.total_seconds * @multiplier
      jitter_range = temp - @min.total_seconds
      jitter = jitter_range > 0 ? Random.rand * jitter_range : 0.0
      next_value = @min.total_seconds + jitter

      # Clamp to bounds
      @current = Time::Span.new(nanoseconds: (next_value * 1_000_000_000).to_i64)
      @current = @max if @current > @max
      @current = @min if @current < @min

      @current
    end

    # Reset the backoff to initial state
    def reset : Nil
      @current = @min
    end

    # Check if the given attempt number is within retry limit
    def should_retry?(attempt : Int32) : Bool
      attempt < @max_retries
    end

    # Get the current interval without advancing
    def current_interval : Time::Span
      @current
    end
  end
end
