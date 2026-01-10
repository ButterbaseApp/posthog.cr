require "json"

module PostHog
  module FeatureFlags
    # Response types for the /flags API endpoint (v=2)
    #
    # The /flags endpoint returns feature flags and their values for a given user.
    # This module provides typed structures for parsing and working with those responses.

    # Result of a feature flag evaluation
    #
    # Feature flags can return:
    # - `true`/`false` for boolean flags
    # - A variant string for multivariate flags
    # - `nil` if the flag is not found or evaluation fails
    alias FlagValue = Bool | String | Nil

    # Reason for flag evaluation result
    struct FlagReason
      getter code : String
      getter condition_index : Int32?
      getter description : String?

      def initialize(@code : String, @condition_index : Int32? = nil, @description : String? = nil)
      end

      def self.from_json_any(data : JSON::Any?) : FlagReason?
        return nil if data.nil?
        return nil unless data.raw.is_a?(Hash)

        code = data["code"]?.try(&.as_s?) || "unknown"
        condition_index = data["condition_index"]?.try(&.as_i?)
        description = data["description"]?.try(&.as_s?)

        new(code, condition_index, description)
      end
    end

    # Metadata associated with a flag evaluation
    struct FlagMetadata
      getter id : Int64?
      getter version : Int64?
      getter payload : JSON::Any?

      def initialize(@id : Int64? = nil, @version : Int64? = nil, @payload : JSON::Any? = nil)
      end

      def self.from_json_any(data : JSON::Any?) : FlagMetadata?
        return nil if data.nil?
        return nil unless data.raw.is_a?(Hash)

        id = data["id"]?.try(&.as_i64?)
        version = data["version"]?.try(&.as_i64?)
        payload_raw = data["payload"]?

        # Payload might be a JSON-encoded string
        payload = if payload_raw
                    if str = payload_raw.as_s?
                      begin
                        JSON.parse(str)
                      rescue
                        payload_raw
                      end
                    else
                      payload_raw
                    end
                  else
                    nil
                  end

        new(id, version, payload)
      end
    end

    # Feature flag with its value and optional payload
    struct Flag
      # The flag key
      getter key : String

      # Whether the flag is enabled
      getter? enabled : Bool

      # The variant (for multivariate flags)
      getter variant : String?

      # Evaluation reason
      getter reason : FlagReason?

      # Flag metadata (id, version, payload)
      getter metadata : FlagMetadata?

      def initialize(
        @key : String,
        @enabled : Bool = false,
        @variant : String? = nil,
        @reason : FlagReason? = nil,
        @metadata : FlagMetadata? = nil
      )
      end

      # Get the flag value (true, false, or variant string)
      def value : FlagValue
        if @variant
          @variant
        else
          @enabled
        end
      end

      # Get the payload from metadata
      def payload : JSON::Any?
        @metadata.try(&.payload)
      end

      def self.from_json_any(key : String, data : JSON::Any) : Flag
        return new(key) unless data.raw.is_a?(Hash)

        enabled = data["enabled"]?.try(&.as_bool?) || false
        variant = data["variant"]?.try(&.as_s?)
        reason = FlagReason.from_json_any(data["reason"]?)
        metadata = FlagMetadata.from_json_any(data["metadata"]?)

        new(key, enabled, variant, reason, metadata)
      end
    end

    # Parsed response from the /flags API endpoint (v=2)
    #
    # Example JSON response:
    # ```json
    # {
    #   "flags": {
    #     "my-flag": {
    #       "key": "my-flag",
    #       "enabled": true,
    #       "variant": "control",
    #       "reason": {"code": "condition_match", "description": "Matched"},
    #       "metadata": {"id": 1, "version": 1, "payload": "{\"key\":\"value\"}"}
    #     }
    #   },
    #   "errorsWhileComputingFlags": false,
    #   "requestId": "uuid"
    # }
    # ```
    class DecideResponse
      # Parsed flags keyed by flag name
      getter flags : Hash(String, Flag)

      # Raw feature flag values keyed by flag name (for backward compat)
      getter feature_flags : Hash(String, FlagValue)

      # Optional payloads keyed by flag name
      getter feature_flag_payloads : Hash(String, JSON::Any)

      # Whether there were errors computing any flags
      getter errors_while_computing_flags : Bool

      # Quota-limited features (array or bool)
      getter quota_limited : Array(String)

      # Request ID for debugging
      getter request_id : String?

      # Timestamp when flags were evaluated
      getter evaluated_at : Int64?

      def initialize(
        @flags : Hash(String, Flag) = Hash(String, Flag).new,
        @feature_flags : Hash(String, FlagValue) = Hash(String, FlagValue).new,
        @feature_flag_payloads : Hash(String, JSON::Any) = Hash(String, JSON::Any).new,
        @errors_while_computing_flags : Bool = false,
        @quota_limited : Array(String) = [] of String,
        @request_id : String? = nil,
        @evaluated_at : Int64? = nil
      )
      end

      # Check if quota limited
      def quota_limited? : Bool
        !@quota_limited.empty?
      end

      # Parse a JSON response from the /flags endpoint
      def self.from_json(json_string : String) : DecideResponse
        data = JSON.parse(json_string)
        from_json_any(data)
      end

      # Parse from already-parsed JSON::Any
      def self.from_json_any(data : JSON::Any) : DecideResponse
        flags = Hash(String, Flag).new
        feature_flags = Hash(String, FlagValue).new
        feature_flag_payloads = Hash(String, JSON::Any).new

        # Parse v2 format: "flags" object with detailed flag info
        flags_data = data["flags"]?
        if flags_data && flags_data.raw.is_a?(Hash)
          flags_data.as_h.each do |key, value|
            if value.raw.is_a?(Hash)
              # v2 format: detailed flag object
              flag = Flag.from_json_any(key, value)
              flags[key] = flag
              feature_flags[key] = flag.value
              if payload = flag.payload
                feature_flag_payloads[key] = payload
              end
            else
              # Simple value format
              feature_flags[key] = parse_flag_value(value)
            end
          end
        end

        # Also check legacy v3/v4 format: "featureFlags" object with simple values
        legacy_flags_data = data["featureFlags"]?
        if legacy_flags_data && legacy_flags_data.raw.is_a?(Hash)
          legacy_flags_data.as_h.each do |key, value|
            unless feature_flags.has_key?(key)
              feature_flags[key] = parse_flag_value(value)
            end
          end
        end

        # Parse legacy payloads format
        payloads_data = data["featureFlagPayloads"]?
        if payloads_data && payloads_data.raw.is_a?(Hash)
          payloads_data.as_h.each do |key, value|
            unless feature_flag_payloads.has_key?(key)
              feature_flag_payloads[key] = parse_payload(value)
            end
          end
        end

        errors = data["errorsWhileComputingFlags"]?.try(&.as_bool?) || false

        # quotaLimited can be bool or array
        quota_limited = [] of String
        if ql = data["quotaLimited"]?
          case ql.raw
          when Bool
            quota_limited = ["feature_flags"] if ql.as_bool
          when Array
            quota_limited = ql.as_a.compact_map(&.as_s?)
          end
        end

        request_id = data["requestId"]?.try(&.as_s?)
        evaluated_at = data["evaluatedAt"]?.try(&.as_i64?)

        new(
          flags: flags,
          feature_flags: feature_flags,
          feature_flag_payloads: feature_flag_payloads,
          errors_while_computing_flags: errors,
          quota_limited: quota_limited,
          request_id: request_id,
          evaluated_at: evaluated_at
        )
      end

      # Create an empty/error response
      def self.empty(quota_limited : Bool = false) : DecideResponse
        ql = quota_limited ? ["feature_flags"] : [] of String
        new(quota_limited: ql)
      end

      # Get a specific flag's value
      def get_flag(key : String) : FlagValue
        @feature_flags[key]?
      end

      # Get a specific flag object (v2 format)
      def get_flag_object(key : String) : Flag?
        @flags[key]?
      end

      # Get a specific flag's payload
      def get_payload(key : String) : JSON::Any?
        @feature_flag_payloads[key]?
      end

      # Get flag reason (v2 format)
      def get_flag_reason(key : String) : FlagReason?
        @flags[key]?.try(&.reason)
      end

      # Get flag metadata (v2 format)
      def get_flag_metadata(key : String) : FlagMetadata?
        @flags[key]?.try(&.metadata)
      end

      # Check if a flag is enabled
      def flag_enabled?(key : String) : Bool?
        value = @feature_flags[key]?
        return nil if value.nil?

        case v = value
        when Bool
          v
        when String
          true # Any variant string means enabled
        else
          false
        end
      end

      # Check if any flags are present
      def empty? : Bool
        @feature_flags.empty?
      end

      private def self.parse_flag_value(value : JSON::Any) : FlagValue
        case raw = value.raw
        when Bool
          raw
        when String
          raw
        when Nil
          nil
        else
          # Numbers or other types - convert to string if truthy
          nil
        end
      end

      private def self.parse_payload(value : JSON::Any) : JSON::Any
        # Payloads might come as JSON-encoded strings
        if str = value.as_s?
          begin
            JSON.parse(str)
          rescue
            value
          end
        else
          value
        end
      end
    end

    # Request body for the /decide endpoint
    struct DecideRequest
      include JSON::Serializable

      @[JSON::Field(key: "api_key")]
      property api_key : String

      @[JSON::Field(key: "distinct_id")]
      property distinct_id : String

      @[JSON::Field(key: "groups", emit_null: false)]
      property groups : Hash(String, String)?

      @[JSON::Field(key: "person_properties", emit_null: false)]
      property person_properties : Hash(String, JSON::Any)?

      @[JSON::Field(key: "group_properties", emit_null: false)]
      property group_properties : Hash(String, Hash(String, JSON::Any))?

      @[JSON::Field(key: "geoip_disable", emit_null: false)]
      property geoip_disable : Bool?

      def initialize(
        @api_key : String,
        @distinct_id : String,
        @groups : Hash(String, String)? = nil,
        @person_properties : Hash(String, JSON::Any)? = nil,
        @group_properties : Hash(String, Hash(String, JSON::Any))? = nil,
        @geoip_disable : Bool? = nil
      )
      end
    end
  end
end
