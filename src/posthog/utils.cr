require "uuid"
require "openssl"

module PostHog
  module Utils
    extend self

    # Generate a UUID v4 string for message IDs
    def generate_uuid : String
      UUID.random.to_s
    end

    # Convert a Time to ISO8601 format with milliseconds
    def iso8601(time : Time) : String
      time.to_utc.to_rfc3339(fraction_digits: 3)
    end

    # Convert any Time values in a hash to ISO8601 strings
    def isoify_dates(hash : Hash(String, JSON::Any)) : Hash(String, JSON::Any)
      hash.transform_values do |value|
        case raw = value.raw
        when Time
          JSON::Any.new(iso8601(raw))
        when Hash
          if raw.is_a?(Hash(String, JSON::Any))
            JSON::Any.new(isoify_dates(raw))
          else
            value
          end
        else
          value
        end
      end
    end

    # Check if a string is a valid UUID format
    def valid_uuid?(uuid : String?) : Bool
      return false if uuid.nil?
      !!(uuid =~ /^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i)
    end

    # SHA1 hash for feature flag consistent hashing (used in Phase 4)
    def sha1_hash(key : String, distinct_id : String, salt : String = "") : Float64
      hash_key = OpenSSL::Digest.new("SHA1").update("#{key}.#{distinct_id}#{salt}").final.hexstring
      hash_key[0, 15].to_i64(16).to_f64 / 0xfffffffffffffff_i64.to_f64
    end
  end
end
