require "http/client"
require "json"
require "log"

require "./feature_flags/response"

module PostHog
  # Feature flags client for remote evaluation via the /decide API
  #
  # This provides server-side feature flag evaluation by calling PostHog's
  # /decide endpoint. For low-latency use cases, consider using local evaluation
  # (Phase 4) which requires a personal API key.
  #
  # Example:
  # ```
  # client = PostHog::Client.new(api_key: "phc_xxx")
  #
  # # Check if a flag is enabled
  # if client.feature_enabled?("new-feature", "user_123")
  #   # Show new feature
  # end
  #
  # # Get a multivariate flag value
  # variant = client.feature_flag("experiment", "user_123")
  # case variant
  # when "control"
  #   # Control group
  # when "test"
  #   # Test group
  # end
  #
  # # Get all flags at once
  # flags = client.all_flags("user_123")
  # ```
  class FeatureFlagsClient
    Log = ::Log.for(self)

    alias Properties = Hash(String, JSON::Any)
    alias GroupProperties = Hash(String, Hash(String, JSON::Any))

    # Cache entry for deduplicating $feature_flag_called events
    private struct FlagCallCacheEntry
      getter distinct_id : String
      getter flag_key : String
      getter flag_value : FeatureFlags::FlagValue
      getter payload : JSON::Any?
      getter request_id : String?
      getter evaluated_at : Int64?
      getter reason : String?
      getter version : Int64?
      getter flag_id : Int64?

      def initialize(
        @distinct_id : String,
        @flag_key : String,
        @flag_value : FeatureFlags::FlagValue,
        @payload : JSON::Any? = nil,
        @request_id : String? = nil,
        @evaluated_at : Int64? = nil,
        @reason : String? = nil,
        @version : Int64? = nil,
        @flag_id : Int64? = nil
      )
      end
    end

    # Event data for $feature_flag_called
    struct FeatureFlagCalledEvent
      getter distinct_id : String
      getter flag_key : String
      getter flag_value : FeatureFlags::FlagValue
      getter payload : JSON::Any?
      getter request_id : String?
      getter evaluated_at : Int64?
      getter reason : String?
      getter version : Int64?
      getter flag_id : Int64?
      getter locally_evaluated : Bool

      def initialize(
        @distinct_id : String,
        @flag_key : String,
        @flag_value : FeatureFlags::FlagValue,
        @payload : JSON::Any? = nil,
        @request_id : String? = nil,
        @evaluated_at : Int64? = nil,
        @reason : String? = nil,
        @version : Int64? = nil,
        @flag_id : Int64? = nil,
        @locally_evaluated : Bool = false
      )
      end

      # Convert to properties hash for capture
      def to_properties : Hash(String, JSON::Any)
        props = Hash(String, JSON::Any).new

        props["$feature_flag"] = JSON::Any.new(@flag_key)

        # Convert flag value to JSON::Any
        props["$feature_flag_response"] = case v = @flag_value
                                          when Bool
                                            JSON::Any.new(v)
                                          when String
                                            JSON::Any.new(v)
                                          else
                                            JSON::Any.new(nil)
                                          end

        # Also add as $feature/{key} property
        props["$feature/#{@flag_key}"] = props["$feature_flag_response"]

        props["locally_evaluated"] = JSON::Any.new(@locally_evaluated)

        if p = @payload
          props["$feature_flag_payload"] = p
        end

        if rid = @request_id
          props["$feature_flag_request_id"] = JSON::Any.new(rid)
        end

        if eat = @evaluated_at
          props["$feature_flag_evaluated_at"] = JSON::Any.new(eat)
        end

        if r = @reason
          props["$feature_flag_reason"] = JSON::Any.new(r)
        end

        if v = @version
          props["$feature_flag_version"] = JSON::Any.new(v)
        end

        if fid = @flag_id
          props["$feature_flag_id"] = JSON::Any.new(fid)
        end

        props
      end
    end

    @config : Config
    @http_client : HTTP::Client?
    @flag_call_cache : Hash(String, FlagCallCacheEntry)
    @flag_call_cache_mutex : Mutex

    def initialize(@config : Config)
      @http_client = nil
      @flag_call_cache = Hash(String, FlagCallCacheEntry).new
      @flag_call_cache_mutex = Mutex.new
    end

    # Check if a feature flag is enabled for a user
    #
    # Returns:
    # - `true` if the flag is enabled
    # - `false` if the flag is disabled
    # - `nil` if the flag is not found or there was an error
    #
    # Options:
    # - `groups` - Group memberships for group-based flags
    # - `person_properties` - Properties for person-based targeting
    # - `group_properties` - Properties for group-based targeting
    # - `only_evaluate_locally` - Skip server fallback (Phase 4 only)
    def feature_enabled?(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil,
      only_evaluate_locally : Bool = false
    ) : Bool?
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      return nil if response.nil?

      value = response.flag_enabled?(key)

      # Track flag evaluation if we got a result
      unless value.nil?
        track_flag_call(key, distinct_id, response, response.get_flag(key))
      end

      value
    end

    # Get the value of a feature flag
    #
    # Returns:
    # - `true` or `false` for boolean flags
    # - A variant string for multivariate flags
    # - `nil` if the flag is not found or there was an error
    def feature_flag(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil,
      only_evaluate_locally : Bool = false
    ) : FeatureFlags::FlagValue
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      return nil if response.nil?

      value = response.get_flag(key)

      # Track flag evaluation if we got a result
      unless value.nil?
        track_flag_call(key, distinct_id, response, value)
      end

      value
    end

    # Get all feature flags for a user
    #
    # Returns a hash of flag keys to their values (true, false, or variant string)
    def all_flags(
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil,
      only_evaluate_locally : Bool = false
    ) : Hash(String, FeatureFlags::FlagValue)
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      return Hash(String, FeatureFlags::FlagValue).new if response.nil?

      response.feature_flags
    end

    # Get the payload for a specific feature flag
    #
    # Feature flag payloads allow you to attach JSON data to flag variants.
    # Returns `nil` if the flag has no payload or doesn't exist.
    def feature_flag_payload(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil,
      only_evaluate_locally : Bool = false
    ) : JSON::Any?
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      return nil if response.nil?

      response.get_payload(key)
    end

    # Get all flags and their payloads for a user
    #
    # Returns a NamedTuple with:
    # - `flags` - Hash of flag keys to values
    # - `payloads` - Hash of flag keys to payloads
    def all_flags_and_payloads(
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil,
      only_evaluate_locally : Bool = false
    ) : NamedTuple(flags: Hash(String, FeatureFlags::FlagValue), payloads: Hash(String, JSON::Any))
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      if response.nil?
        return {
          flags:    Hash(String, FeatureFlags::FlagValue).new,
          payloads: Hash(String, JSON::Any).new,
        }
      end

      {
        flags:    response.feature_flags,
        payloads: response.feature_flag_payloads,
      }
    end

    # Get flags to inject into a capture event when send_feature_flags is true
    #
    # Returns the feature variants hash to pass to FieldParser.parse_for_capture
    def get_feature_variants_for_capture(
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : GroupProperties? = nil
    ) : Hash(String, JSON::Any)?
      response = fetch_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      )

      return nil if response.nil? || response.empty?

      # Convert FlagValue to JSON::Any
      result = Hash(String, JSON::Any).new
      response.feature_flags.each do |key, value|
        result[key] = case v = value
                      when Bool
                        JSON::Any.new(v)
                      when String
                        JSON::Any.new(v)
                      else
                        JSON::Any.new(false)
                      end
      end

      result.empty? ? nil : result
    end

    # Get pending $feature_flag_called events and clear the cache
    #
    # Returns an array of event data to be captured
    def flush_flag_call_events : Array(FeatureFlagCalledEvent)
      events = [] of FeatureFlagCalledEvent

      @flag_call_cache_mutex.synchronize do
        @flag_call_cache.each do |_, entry|
          events << FeatureFlagCalledEvent.new(
            distinct_id: entry.distinct_id,
            flag_key: entry.flag_key,
            flag_value: entry.flag_value,
            payload: entry.payload,
            request_id: entry.request_id,
            evaluated_at: entry.evaluated_at,
            reason: entry.reason,
            version: entry.version,
            flag_id: entry.flag_id,
            locally_evaluated: false
          )
        end
        @flag_call_cache.clear
      end

      events
    end

    # Check if there are pending flag call events
    def has_pending_flag_calls? : Bool
      @flag_call_cache_mutex.synchronize do
        !@flag_call_cache.empty?
      end
    end

    # Shutdown and cleanup
    def shutdown : Nil
      @http_client.try(&.close)
      @http_client = nil
    end

    private def fetch_flags(
      distinct_id : String,
      groups : Hash(String, String)?,
      person_properties : Properties?,
      group_properties : GroupProperties?
    ) : FeatureFlags::DecideResponse?
      request = FeatureFlags::DecideRequest.new(
        api_key: @config.api_key,
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        geoip_disable: true
      )

      begin
        client = get_http_client
        headers = build_headers

        response = client.post("/flags?v=2", headers: headers, body: request.to_json)

        case response.status_code
        when 200..299
          FeatureFlags::DecideResponse.from_json(response.body)
        when 402
          # Quota limited
          Log.warn { "Feature flags quota limited" }
          FeatureFlags::DecideResponse.empty(quota_limited: true)
        when 401, 403
          Log.error { "Feature flags authentication error: #{response.status_code}" }
          report_error(response.status_code, "Authentication error")
          nil
        else
          Log.error { "Feature flags request failed: #{response.status_code}" }
          report_error(response.status_code, "Request failed")
          nil
        end
      rescue ex : Socket::Error | IO::Error | OpenSSL::SSL::Error
        Log.error { "Feature flags network error: #{ex.message}" }
        report_error(-1, ex.message || "Network error")
        nil
      rescue ex : IO::TimeoutError
        Log.error { "Feature flags timeout" }
        report_error(-1, "Request timeout")
        nil
      rescue ex : JSON::ParseException
        Log.error { "Feature flags JSON parse error: #{ex.message}" }
        report_error(-1, "Invalid response")
        nil
      end
    end

    private def track_flag_call(
      key : String,
      distinct_id : String,
      response : FeatureFlags::DecideResponse,
      value : FeatureFlags::FlagValue
    ) : Nil
      cache_key = "#{distinct_id}:#{key}:#{value}"

      @flag_call_cache_mutex.synchronize do
        unless @flag_call_cache.has_key?(cache_key)
          # Extract additional info from v2 response if available
          flag_obj = response.get_flag_object(key)
          metadata = flag_obj.try(&.metadata)
          reason = flag_obj.try(&.reason)

          @flag_call_cache[cache_key] = FlagCallCacheEntry.new(
            distinct_id: distinct_id,
            flag_key: key,
            flag_value: value,
            payload: response.get_payload(key),
            request_id: response.request_id,
            evaluated_at: response.evaluated_at,
            reason: reason.try(&.description),
            version: metadata.try(&.version),
            flag_id: metadata.try(&.id)
          )
        end
      end
    end

    private def get_http_client : HTTP::Client
      @http_client ||= begin
        uri = URI.parse(@config.normalized_host)

        tls_context = if @config.skip_ssl_verification && uri.scheme == "https"
                        ctx = OpenSSL::SSL::Context::Client.new
                        ctx.verify_mode = OpenSSL::SSL::VerifyMode::NONE
                        ctx
                      elsif uri.scheme == "https"
                        OpenSSL::SSL::Context::Client.new
                      else
                        nil
                      end

        client = HTTP::Client.new(uri, tls: tls_context)
        client.read_timeout = @config.feature_flag_request_timeout
        client.connect_timeout = @config.feature_flag_request_timeout
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

    private def report_error(status : Int32, error : String) : Nil
      @config.on_error.try(&.call(status, error))
    end
  end
end
