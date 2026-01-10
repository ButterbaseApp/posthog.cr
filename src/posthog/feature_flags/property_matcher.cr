require "json"
require "regex"

require "./errors"

module PostHog
  module FeatureFlags
    # Property matching engine for feature flag conditions.
    #
    # Supports all PostHog property operators:
    # - exact, is_not: Equality matching (case-insensitive)
    # - is_set, is_not_set: Property existence checks
    # - icontains, not_icontains: Substring matching (case-insensitive)
    # - regex, not_regex: Regular expression matching
    # - gt, gte, lt, lte: Numeric/string comparisons
    # - is_date_before, is_date_after: Date comparisons with relative date support
    module PropertyMatcher
      extend self

      # Type alias for property values hash
      alias PropertyValues = Hash(String, JSON::Any)

      # Supported operators
      OPERATORS = {
        "exact", "is_not",
        "is_set", "is_not_set",
        "icontains", "not_icontains",
        "regex", "not_regex",
        "gt", "gte", "lt", "lte",
        "is_date_before", "is_date_after",
      }

      # Regex for parsing relative dates like "-7d", "-1h", "-2w", "-3m", "-1y"
      RELATIVE_DATE_REGEX = /^-?(\d+)([hdwmy])$/i

      # Maximum number for relative date to prevent overflow
      MAX_RELATIVE_DATE_VALUE = 10_000

      # Match a property condition against provided property values.
      #
      # Raises InconclusiveMatchError if:
      # - Property key is missing from values (except for is_not_set)
      # - Invalid regex pattern
      # - Invalid date format
      #
      # Example:
      # ```
      # property = {
      #   "key" => JSON::Any.new("email"),
      #   "operator" => JSON::Any.new("icontains"),
      #   "value" => JSON::Any.new("@example.com")
      # }
      # values = {"email" => JSON::Any.new("user@example.com")}
      # PropertyMatcher.match(property, values) # => true
      # ```
      def match(property : Hash(String, JSON::Any), property_values : PropertyValues) : Bool
        key = property["key"]?.try(&.as_s?)
        raise InconclusiveMatchError.new("Property missing 'key' field") unless key

        operator = property["operator"]?.try(&.as_s?) || "exact"
        value = property["value"]?

        # Handle is_not_set specially - it checks for absence
        if operator == "is_not_set"
          return !property_values.has_key?(key)
        end

        # For all other operators, the property must exist
        unless property_values.has_key?(key)
          raise InconclusiveMatchError.new("Property '#{key}' not found in property values")
        end

        override_value = property_values[key]

        case operator
        when "exact"
          match_exact(value, override_value)
        when "is_not"
          !match_exact(value, override_value)
        when "is_set"
          true # We already checked existence above
        when "icontains"
          match_icontains(value, override_value)
        when "not_icontains"
          !match_icontains(value, override_value)
        when "regex"
          match_regex(value, override_value)
        when "not_regex"
          !match_regex(value, override_value)
        when "gt"
          match_comparison(value, override_value, :gt)
        when "gte"
          match_comparison(value, override_value, :gte)
        when "lt"
          match_comparison(value, override_value, :lt)
        when "lte"
          match_comparison(value, override_value, :lte)
        when "is_date_before"
          match_date_comparison(value, override_value, :before)
        when "is_date_after"
          match_date_comparison(value, override_value, :after)
        else
          raise InconclusiveMatchError.new("Unknown operator: #{operator}")
        end
      end

      # Exact match (case-insensitive for strings)
      # Supports both single values and arrays (matches if any element matches)
      private def match_exact(value : JSON::Any?, override_value : JSON::Any) : Bool
        return false if value.nil?

        # Handle array values - match if override is in the array
        if arr = value.as_a?
          override_str = stringify(override_value).downcase
          return arr.any? { |v| stringify(v).downcase == override_str }
        end

        # Single value comparison (case-insensitive for strings)
        str_iequals(value, override_value)
      end

      # Case-insensitive substring match
      private def match_icontains(value : JSON::Any?, override_value : JSON::Any) : Bool
        return false if value.nil?

        override_str = stringify(override_value).downcase
        value_str = stringify(value).downcase

        override_str.includes?(value_str)
      end

      # Regular expression match
      private def match_regex(value : JSON::Any?, override_value : JSON::Any) : Bool
        return false if value.nil?

        pattern = stringify(value)
        override_str = stringify(override_value)

        begin
          regex = Regex.new(pattern)
          !!(regex.match(override_str))
        rescue ex : ArgumentError
          # Invalid regex pattern
          raise InconclusiveMatchError.new("Invalid regex pattern: #{pattern}")
        end
      end

      # Numeric or string comparison
      private def match_comparison(
        value : JSON::Any?,
        override_value : JSON::Any,
        op : Symbol
      ) : Bool
        return false if value.nil?

        # Try numeric comparison first
        parsed_value = to_number(value)
        parsed_override = to_number(override_value)

        if parsed_value && parsed_override
          compare(parsed_override, parsed_value, op)
        else
          # Fall back to string comparison
          compare(stringify(override_value), stringify(value), op)
        end
      end

      # Date comparison with support for relative dates
      private def match_date_comparison(
        value : JSON::Any?,
        override_value : JSON::Any,
        op : Symbol
      ) : Bool
        return false if value.nil?

        # Parse the condition value (may be relative date like "-7d")
        parsed_date = parse_date_value(stringify(value))
        unless parsed_date
          raise InconclusiveMatchError.new("Invalid date value: #{value}")
        end

        # Parse the override value
        override_date = parse_override_date(override_value)
        unless override_date
          raise InconclusiveMatchError.new("Invalid date in property: #{override_value}")
        end

        case op
        when :before
          override_date < parsed_date
        when :after
          override_date > parsed_date
        else
          false
        end
      end

      # Parse a date value that may be absolute or relative
      private def parse_date_value(value : String) : Time?
        # Try relative date first (e.g., "-7d", "-1h")
        if relative = parse_relative_date(value)
          return relative
        end

        # Try absolute date formats
        parse_absolute_date(value)
      end

      # Parse relative date strings like "-7d", "-1h", "-2w", "-3m", "-1y"
      private def parse_relative_date(value : String) : Time?
        match = RELATIVE_DATE_REGEX.match(value)
        return nil unless match

        number = match[1].to_i
        return nil if number >= MAX_RELATIVE_DATE_VALUE # Guard against overflow

        interval = match[2].downcase
        now = Time.utc

        case interval
        when "h"
          now - number.hours
        when "d"
          now - number.days
        when "w"
          now - (number * 7).days
        when "m"
          now - number.months
        when "y"
          now - number.years
        else
          nil
        end
      end

      # Parse absolute date strings in various formats
      private def parse_absolute_date(value : String) : Time?
        # Try common formats
        formats = [
          Time::Format::RFC_3339,
          Time::Format::ISO_8601_DATE_TIME,
          Time::Format::ISO_8601_DATE,
        ]

        formats.each do |format|
          begin
            return format.parse(value)
          rescue Time::Format::Error
            # Try next format
          end
        end

        # Try simple date format (YYYY-MM-DD)
        begin
          return Time.parse(value, "%Y-%m-%d", Time::Location::UTC)
        rescue Time::Format::Error
        end

        # Try datetime without timezone
        begin
          return Time.parse(value, "%Y-%m-%dT%H:%M:%S", Time::Location::UTC)
        rescue Time::Format::Error
        end

        nil
      end

      # Parse override value that might be a Time, string date, or timestamp
      private def parse_override_date(value : JSON::Any) : Time?
        case raw = value.raw
        when Int64
          # Unix timestamp (seconds)
          Time.unix(raw)
        when Float64
          # Unix timestamp with fractional seconds
          Time.unix(raw.to_i64)
        when String
          parse_absolute_date(raw)
        else
          nil
        end
      end

      # Generic comparison helper
      private def compare(lhs : T, rhs : T, op : Symbol) : Bool forall T
        case op
        when :gt
          lhs > rhs
        when :gte
          lhs >= rhs
        when :lt
          lhs < rhs
        when :lte
          lhs <= rhs
        else
          false
        end
      end

      # Case-insensitive string equality
      private def str_iequals(a : JSON::Any, b : JSON::Any) : Bool
        stringify(a).downcase == stringify(b).downcase
      end

      # Convert JSON::Any to string representation
      private def stringify(value : JSON::Any) : String
        case raw = value.raw
        when String
          raw
        when Bool
          raw.to_s
        when Int64, Float64
          raw.to_s
        when Nil
          ""
        else
          value.to_json
        end
      end

      # Try to convert JSON::Any to a number
      private def to_number(value : JSON::Any) : Float64?
        case raw = value.raw
        when Int64
          raw.to_f64
        when Float64
          raw
        when String
          raw.to_f64?
        else
          nil
        end
      end
    end
  end
end
