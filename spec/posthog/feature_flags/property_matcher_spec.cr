require "../../spec_helper"

private def make_prop(key : String, operator : String, value : JSON::Any) : Hash(String, JSON::Any)
  {
    "key"      => JSON::Any.new(key),
    "operator" => JSON::Any.new(operator),
    "value"    => value,
  }
end

private def make_vals(hash : Hash(String, String)) : Hash(String, JSON::Any)
  hash.transform_values { |v| JSON::Any.new(v) }
end

describe PostHog::FeatureFlags::PropertyMatcher do
  describe "exact operator" do
    it "matches exact string (case-insensitive)" do
      prop = make_prop("email", "exact", JSON::Any.new("user@example.com"))
      values = make_vals({"email" => "USER@EXAMPLE.COM"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match different strings" do
      prop = make_prop("email", "exact", JSON::Any.new("user@example.com"))
      values = make_vals({"email" => "other@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end

    it "matches when value is in array" do
      prop = make_prop("plan", "exact", JSON::Any.new([JSON::Any.new("free"), JSON::Any.new("basic")]))
      values = make_vals({"plan" => "BASIC"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when value not in array" do
      prop = make_prop("plan", "exact", JSON::Any.new([JSON::Any.new("free"), JSON::Any.new("basic")]))
      values = make_vals({"plan" => "premium"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "is_not operator" do
    it "matches when values differ" do
      prop = make_prop("plan", "is_not", JSON::Any.new("free"))
      values = make_vals({"plan" => "premium"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when values same (case-insensitive)" do
      prop = make_prop("plan", "is_not", JSON::Any.new("free"))
      values = make_vals({"plan" => "FREE"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "is_set operator" do
    it "matches when property exists" do
      prop = make_prop("email", "is_set", JSON::Any.new(nil))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "raises InconclusiveMatchError when property missing" do
      prop = make_prop("email", "is_set", JSON::Any.new(nil))
      values = Hash(String, JSON::Any).new

      expect_raises(PostHog::FeatureFlags::InconclusiveMatchError) do
        PostHog::FeatureFlags::PropertyMatcher.match(prop, values)
      end
    end
  end

  describe "is_not_set operator" do
    it "matches when property does not exist" do
      prop = make_prop("email", "is_not_set", JSON::Any.new(nil))
      values = Hash(String, JSON::Any).new

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when property exists" do
      prop = make_prop("email", "is_not_set", JSON::Any.new(nil))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "icontains operator" do
    it "matches substring (case-insensitive)" do
      prop = make_prop("email", "icontains", JSON::Any.new("example"))
      values = make_vals({"email" => "user@EXAMPLE.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when substring missing" do
      prop = make_prop("email", "icontains", JSON::Any.new("test"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "not_icontains operator" do
    it "matches when substring missing" do
      prop = make_prop("email", "not_icontains", JSON::Any.new("test"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when substring present" do
      prop = make_prop("email", "not_icontains", JSON::Any.new("example"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "regex operator" do
    it "matches regex pattern" do
      prop = make_prop("email", "regex", JSON::Any.new(".*@example\\.com$"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when pattern doesn't match" do
      prop = make_prop("email", "regex", JSON::Any.new(".*@test\\.com$"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end

    it "raises InconclusiveMatchError for invalid regex" do
      prop = make_prop("email", "regex", JSON::Any.new("[invalid("))
      values = make_vals({"email" => "user@example.com"})

      expect_raises(PostHog::FeatureFlags::InconclusiveMatchError, /Invalid regex/) do
        PostHog::FeatureFlags::PropertyMatcher.match(prop, values)
      end
    end
  end

  describe "not_regex operator" do
    it "matches when regex doesn't match" do
      prop = make_prop("email", "not_regex", JSON::Any.new(".*@test\\.com$"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "does not match when regex matches" do
      prop = make_prop("email", "not_regex", JSON::Any.new(".*@example\\.com$"))
      values = make_vals({"email" => "user@example.com"})

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end
  end

  describe "numeric comparison operators" do
    it "gt: matches greater than" do
      prop = make_prop("age", "gt", JSON::Any.new(18))
      values = {"age" => JSON::Any.new(25)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "gt: does not match equal" do
      prop = make_prop("age", "gt", JSON::Any.new(18))
      values = {"age" => JSON::Any.new(18)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_false
    end

    it "gte: matches equal" do
      prop = make_prop("age", "gte", JSON::Any.new(18))
      values = {"age" => JSON::Any.new(18)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "lt: matches less than" do
      prop = make_prop("score", "lt", JSON::Any.new(100.5))
      values = {"score" => JSON::Any.new(50.0)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "lte: matches equal" do
      prop = make_prop("score", "lte", JSON::Any.new(100))
      values = {"score" => JSON::Any.new(100)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "handles string to number conversion" do
      prop = make_prop("version", "gt", JSON::Any.new("2.0"))
      values = {"version" => JSON::Any.new(2.5)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end
  end

  describe "date comparison operators" do
    it "is_date_before: matches earlier date" do
      prop = make_prop("signup_date", "is_date_before", JSON::Any.new("2024-01-01"))
      values = {"signup_date" => JSON::Any.new("2023-06-15")}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "is_date_after: matches later date" do
      prop = make_prop("signup_date", "is_date_after", JSON::Any.new("2024-01-01"))
      values = {"signup_date" => JSON::Any.new("2024-06-15")}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "is_date_before: handles relative dates like -7d" do
      prop = make_prop("last_seen", "is_date_before", JSON::Any.new("-7d"))
      # 14 days ago should be before -7d (7 days ago)
      old_date = (Time.utc - 14.days).to_rfc3339
      values = {"last_seen" => JSON::Any.new(old_date)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "is_date_after: handles relative dates like -1h" do
      prop = make_prop("last_seen", "is_date_after", JSON::Any.new("-1h"))
      # 30 minutes ago should be after -1h
      recent_date = (Time.utc - 30.minutes).to_rfc3339
      values = {"last_seen" => JSON::Any.new(recent_date)}

      PostHog::FeatureFlags::PropertyMatcher.match(prop, values).should be_true
    end

    it "raises InconclusiveMatchError for invalid date" do
      prop = make_prop("date", "is_date_before", JSON::Any.new("not-a-date"))
      values = {"date" => JSON::Any.new("2024-01-01")}

      expect_raises(PostHog::FeatureFlags::InconclusiveMatchError, /Invalid date/) do
        PostHog::FeatureFlags::PropertyMatcher.match(prop, values)
      end
    end
  end

  describe "missing property" do
    it "raises InconclusiveMatchError when property key missing" do
      prop = make_prop("missing", "exact", JSON::Any.new("value"))
      values = make_vals({"other" => "value"})

      expect_raises(PostHog::FeatureFlags::InconclusiveMatchError, /not found/) do
        PostHog::FeatureFlags::PropertyMatcher.match(prop, values)
      end
    end
  end

  describe "unknown operator" do
    it "raises InconclusiveMatchError" do
      prop = make_prop("key", "unknown_op", JSON::Any.new("value"))
      values = make_vals({"key" => "value"})

      expect_raises(PostHog::FeatureFlags::InconclusiveMatchError, /Unknown operator/) do
        PostHog::FeatureFlags::PropertyMatcher.match(prop, values)
      end
    end
  end
end
