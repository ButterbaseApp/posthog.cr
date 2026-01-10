require "../spec_helper"

describe PostHog::BackoffPolicy do
  describe "#initialize" do
    it "creates policy with default values" do
      policy = PostHog::BackoffPolicy.new

      policy.min.should eq PostHog::Defaults::BACKOFF_MIN
      policy.max.should eq PostHog::Defaults::BACKOFF_MAX
      policy.multiplier.should eq PostHog::Defaults::BACKOFF_MULTIPLIER
      policy.max_retries.should eq PostHog::Defaults::MAX_RETRIES
    end

    it "accepts custom values" do
      policy = PostHog::BackoffPolicy.new(
        min: 50.milliseconds,
        max: 5.seconds,
        multiplier: 2.0,
        max_retries: 5
      )

      policy.min.should eq 50.milliseconds
      policy.max.should eq 5.seconds
      policy.multiplier.should eq 2.0
      policy.max_retries.should eq 5
    end
  end

  describe "#next_interval" do
    it "returns interval within min/max bounds" do
      policy = PostHog::BackoffPolicy.new(
        min: 100.milliseconds,
        max: 10.seconds
      )

      10.times do
        interval = policy.next_interval
        interval.should be >= 100.milliseconds
        interval.should be <= 10.seconds
      end
    end

    it "starts at minimum interval" do
      policy = PostHog::BackoffPolicy.new(
        min: 100.milliseconds,
        max: 10.seconds
      )

      # First interval should be around min
      interval = policy.next_interval
      interval.should be >= 100.milliseconds
      interval.should be <= 250.milliseconds # Some jitter allowance
    end

    it "generally increases over time" do
      policy = PostHog::BackoffPolicy.new(
        min: 100.milliseconds,
        max: 10.seconds,
        multiplier: 2.0
      )

      intervals = (0..5).map { policy.next_interval }

      # Due to jitter, we can't guarantee strict increase,
      # but later intervals should generally be larger
      # Check that average of last 3 is larger than average of first 3
      first_avg = intervals[0..2].map(&.total_seconds).sum / 3.0
      last_avg = intervals[3..5].map(&.total_seconds).sum / 3.0
      last_avg.should be >= first_avg
    end

    it "never exceeds max" do
      policy = PostHog::BackoffPolicy.new(
        min: 100.milliseconds,
        max: 1.second,
        multiplier: 3.0
      )

      # Call many times to ensure we hit the ceiling
      20.times do
        interval = policy.next_interval
        interval.should be <= 1.second
      end
    end
  end

  describe "#reset" do
    it "resets to initial state" do
      policy = PostHog::BackoffPolicy.new(
        min: 100.milliseconds,
        max: 10.seconds,
        multiplier: 2.0
      )

      # Advance the policy
      5.times { policy.next_interval }

      # Reset
      policy.reset

      # Should be back at min
      policy.current_interval.should eq 100.milliseconds
    end
  end

  describe "#should_retry?" do
    it "returns true for attempts within limit" do
      policy = PostHog::BackoffPolicy.new(max_retries: 3)

      policy.should_retry?(0).should be_true
      policy.should_retry?(1).should be_true
      policy.should_retry?(2).should be_true
    end

    it "returns false for attempts at or beyond limit" do
      policy = PostHog::BackoffPolicy.new(max_retries: 3)

      policy.should_retry?(3).should be_false
      policy.should_retry?(4).should be_false
      policy.should_retry?(10).should be_false
    end
  end

  describe "#current_interval" do
    it "returns current interval without advancing" do
      policy = PostHog::BackoffPolicy.new(min: 100.milliseconds)

      initial = policy.current_interval
      same = policy.current_interval

      initial.should eq same
      initial.should eq 100.milliseconds
    end
  end
end
