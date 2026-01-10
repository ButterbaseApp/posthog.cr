require "log"

module PostHog
  # The main PostHog client for capturing events and managing feature flags
  class Client
    Log = ::Log.for(self)

    # Alias for properties hash type
    alias Properties = Hash(String, JSON::Any)

    @config : Config
    @transport : Transport
    @worker : Worker?
    @message_channel : Channel(Message)
    @control_channel : Channel(Worker::Control)
    @queue_size : Atomic(Int32)
    @shutdown : Bool = false
    @feature_flags_client : FeatureFlagsClient

    def initialize(
      api_key : String,
      host : String = Defaults::HOST,
      personal_api_key : String? = nil,
      max_queue_size : Int32 = Defaults::MAX_QUEUE_SIZE,
      batch_size : Int32 = Defaults::BATCH_SIZE,
      request_timeout : Time::Span = Defaults::REQUEST_TIMEOUT,
      skip_ssl_verification : Bool = false,
      async : Bool = true,
      test_mode : Bool = false,
      on_error : Proc(Int32, String, Nil)? = nil,
      before_send : Config::BeforeSendProc? = nil
    )
      @config = Config.new(
        api_key: api_key,
        host: host,
        personal_api_key: personal_api_key,
        max_queue_size: max_queue_size,
        batch_size: batch_size,
        request_timeout: request_timeout,
        skip_ssl_verification: skip_ssl_verification,
        async: async,
        test_mode: test_mode,
        on_error: on_error,
        before_send: before_send
      )

      @transport = Transport.new(
        host: @config.normalized_host,
        timeout: @config.request_timeout,
        skip_ssl_verification: @config.skip_ssl_verification
      )

      @message_channel = Channel(Message).new(@config.max_queue_size)
      @control_channel = Channel(Worker::Control).new(10)
      @queue_size = Atomic(Int32).new(0)
      @feature_flags_client = FeatureFlagsClient.new(@config)

      if @config.async
        on_processed = ->{ @queue_size.sub(1); nil }
        @worker = Worker.new(@config, @transport, @message_channel, @control_channel, on_processed)
        @worker.try(&.start)
      end

      # Start local evaluation poller if personal_api_key is provided
      if @config.personal_api_key
        @feature_flags_client.start_poller
      end
    end

    # Capture an event
    #
    # ```
    # client.capture(
    #   distinct_id: "user_123",
    #   event: "button_clicked",
    #   properties: {"color" => JSON::Any.new("blue")}
    # )
    # ```
    def capture(
      distinct_id : String,
      event : String,
      properties : Properties = Properties.new,
      groups : Hash(String, String)? = nil,
      timestamp : Time = Time.utc,
      uuid : String? = nil,
      send_feature_flags : Bool = false
    ) : Bool
      # Fetch feature flags if requested
      feature_variants = if send_feature_flags
                           @feature_flags_client.get_feature_variants_for_capture(
                             distinct_id: distinct_id,
                             groups: groups
                           )
                         else
                           nil
                         end

      message = FieldParser.parse_for_capture(
        distinct_id: distinct_id,
        event: event,
        properties: properties,
        groups: groups,
        timestamp: timestamp,
        uuid: uuid,
        feature_variants: feature_variants
      )

      enqueue(message)
    rescue ex : FieldParser::ValidationError
      Log.error { "Capture validation error: #{ex.message}" }
      report_error(-1, ex.message || "Validation error")
      false
    end

    # Identify a user with properties
    #
    # ```
    # client.identify(
    #   distinct_id: "user_123",
    #   properties: {"email" => JSON::Any.new("user@example.com")}
    # )
    # ```
    def identify(
      distinct_id : String,
      properties : Properties = Properties.new,
      timestamp : Time = Time.utc
    ) : Bool
      message = FieldParser.parse_for_identify(
        distinct_id: distinct_id,
        properties: properties,
        timestamp: timestamp
      )

      enqueue(message)
    rescue ex : FieldParser::ValidationError
      Log.error { "Identify validation error: #{ex.message}" }
      report_error(-1, ex.message || "Validation error")
      false
    end

    # Create an alias between two user IDs
    #
    # ```
    # client.alias(distinct_id: "user_123", alias_id: "anon_456")
    # ```
    def alias(distinct_id : String, alias_id : String, timestamp : Time = Time.utc) : Bool
      message = FieldParser.parse_for_alias(
        distinct_id: distinct_id,
        alias_id: alias_id,
        timestamp: timestamp
      )

      enqueue(message)
    rescue ex : FieldParser::ValidationError
      Log.error { "Alias validation error: #{ex.message}" }
      report_error(-1, ex.message || "Validation error")
      false
    end

    # Identify a group with properties
    #
    # ```
    # client.group_identify(
    #   group_type: "company",
    #   group_key: "acme_inc",
    #   properties: {"name" => JSON::Any.new("Acme Inc")}
    # )
    # ```
    def group_identify(
      group_type : String,
      group_key : String,
      properties : Properties = Properties.new,
      distinct_id : String? = nil,
      timestamp : Time = Time.utc
    ) : Bool
      message = FieldParser.parse_for_group_identify(
        group_type: group_type,
        group_key: group_key,
        properties: properties,
        distinct_id: distinct_id,
        timestamp: timestamp
      )

      enqueue(message)
    rescue ex : FieldParser::ValidationError
      Log.error { "Group identify validation error: #{ex.message}" }
      report_error(-1, ex.message || "Validation error")
      false
    end

    # ===== Feature Flags API =====

    # Check if local evaluation is enabled (personal_api_key was provided)
    def local_evaluation_enabled? : Bool
      @feature_flags_client.local_evaluation_enabled?
    end

    # Manually reload feature flag definitions from the server.
    #
    # Only works when local evaluation is enabled (personal_api_key provided).
    # Useful for forcing an immediate refresh after flag changes.
    #
    # ```
    # client.reload_feature_flags
    # ```
    def reload_feature_flags : Nil
      @feature_flags_client.reload_feature_flags
    end

    # Check if a feature flag is enabled for a user
    #
    # Returns:
    # - `true` if the flag is enabled
    # - `false` if the flag is disabled
    # - `nil` if the flag is not found or there was an error
    #
    # ```
    # if client.feature_enabled?("new-feature", "user_123")
    #   # Show new feature
    # end
    # ```
    def feature_enabled?(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : Hash(String, Properties)? = nil,
      only_evaluate_locally : Bool = false
    ) : Bool?
      @feature_flags_client.feature_enabled?(
        key: key,
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        only_evaluate_locally: only_evaluate_locally
      )
    end

    # Get the value of a feature flag
    #
    # Returns:
    # - `true` or `false` for boolean flags
    # - A variant string for multivariate flags
    # - `nil` if the flag is not found or there was an error
    #
    # ```
    # variant = client.feature_flag("experiment", "user_123")
    # case variant
    # when "control"
    #   # Control group
    # when "test"
    #   # Test group
    # end
    # ```
    def feature_flag(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : Hash(String, Properties)? = nil,
      only_evaluate_locally : Bool = false
    ) : FeatureFlags::FlagValue
      @feature_flags_client.feature_flag(
        key: key,
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        only_evaluate_locally: only_evaluate_locally
      )
    end

    # Get all feature flags for a user
    #
    # Returns a hash of flag keys to their values (true, false, or variant string)
    #
    # ```
    # flags = client.all_flags("user_123")
    # flags.each do |key, value|
    #   puts "#{key}: #{value}"
    # end
    # ```
    def all_flags(
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : Hash(String, Properties)? = nil,
      only_evaluate_locally : Bool = false
    ) : Hash(String, FeatureFlags::FlagValue)
      @feature_flags_client.all_flags(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        only_evaluate_locally: only_evaluate_locally
      )
    end

    # Get the payload for a specific feature flag
    #
    # Feature flag payloads allow you to attach JSON data to flag variants.
    # Returns `nil` if the flag has no payload or doesn't exist.
    #
    # ```
    # payload = client.feature_flag_payload("my-flag", "user_123")
    # if config = payload
    #   puts config["color"]?
    # end
    # ```
    def feature_flag_payload(
      key : String,
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : Hash(String, Properties)? = nil,
      only_evaluate_locally : Bool = false
    ) : JSON::Any?
      @feature_flags_client.feature_flag_payload(
        key: key,
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        only_evaluate_locally: only_evaluate_locally
      )
    end

    # Get all flags and their payloads for a user
    #
    # Returns a NamedTuple with:
    # - `flags` - Hash of flag keys to values
    # - `payloads` - Hash of flag keys to payloads
    #
    # ```
    # result = client.all_flags_and_payloads("user_123")
    # result[:flags].each { |k, v| puts "Flag #{k}: #{v}" }
    # result[:payloads].each { |k, v| puts "Payload #{k}: #{v}" }
    # ```
    def all_flags_and_payloads(
      distinct_id : String,
      groups : Hash(String, String)? = nil,
      person_properties : Properties? = nil,
      group_properties : Hash(String, Properties)? = nil,
      only_evaluate_locally : Bool = false
    ) : NamedTuple(flags: Hash(String, FeatureFlags::FlagValue), payloads: Hash(String, JSON::Any))
      @feature_flags_client.all_flags_and_payloads(
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties,
        only_evaluate_locally: only_evaluate_locally
      )
    end

    # ===== Lifecycle Methods =====

    # Flush all pending messages synchronously
    # Blocks until the queue is empty
    def flush : Nil
      return if @shutdown

      if @config.async
        @control_channel.send(Worker::Control::Flush)
        # Wait for queue to drain
        while @queue_size.get > 0 || @worker.try(&.requesting?)
          sleep(10.milliseconds)
        end
      end
    end

    # Shutdown the client gracefully
    # Flushes pending messages and stops the worker
    def shutdown : Nil
      return if @shutdown
      @shutdown = true

      # Flush any pending $feature_flag_called events
      flush_feature_flag_events

      if @config.async
        @control_channel.send(Worker::Control::Shutdown)
        # Wait for worker to finish
        while @worker.try(&.running?)
          sleep(10.milliseconds)
        end
      end

      @feature_flags_client.shutdown
      @transport.shutdown
      @message_channel.close
      @control_channel.close
    end

    # Get the current queue size
    def queue_size : Int32
      @queue_size.get
    end

    # Check if the client has been shut down
    def shutdown? : Bool
      @shutdown
    end

    # Flush pending $feature_flag_called events
    private def flush_feature_flag_events : Nil
      events = @feature_flags_client.flush_flag_call_events
      events.each do |event|
        capture(
          distinct_id: event.distinct_id,
          event: "$feature_flag_called",
          properties: event.to_properties
        )
      end
    end

    private def enqueue(message : Message) : Bool
      return false if @shutdown

      # Apply before_send hook
      if hook = @config.before_send
        # Convert message to hash for the hook
        message_hash = message_to_hash(message)
        result = hook.call(message_hash)

        if result.nil?
          Log.debug { "Event #{message.event} dropped by before_send hook" }
          return false
        end

        # Note: In a full implementation, we'd reconstruct the message from the result
        # For now, we continue with the original message if not nil
      end

      if @config.async
        # Check queue size
        if @queue_size.get >= @config.max_queue_size
          Log.warn { "Queue is full (#{@config.max_queue_size}), dropping event" }
          report_error(-1, "Queue is full, dropping events")
          return false
        end

        begin
          @message_channel.send(message)
          @queue_size.add(1)
          true
        rescue Channel::ClosedError
          Log.error { "Cannot enqueue: channel closed" }
          false
        end
      elsif @config.test_mode
        # Test mode: just return true without sending
        true
      else
        # Sync mode: send immediately
        batch = MessageBatch.new(max_size: 1)
        unless batch.add(message).added?
          Log.error { "Failed to add message to batch in sync mode" }
          return false
        end
        response = @transport.send(@config.api_key, batch)
        unless response.success?
          report_error(response.status, response.error_message)
        end
        response.success?
      end
    end

    private def message_to_hash(message : Message) : Properties
      # Convert message to a hash for the before_send hook
      hash = Properties.new
      hash["type"] = JSON::Any.new(message.type)
      hash["event"] = JSON::Any.new(message.event)
      hash["distinct_id"] = JSON::Any.new(message.distinct_id)
      hash["timestamp"] = JSON::Any.new(message.timestamp)
      hash["properties"] = JSON::Any.new(message.properties)
      hash
    end

    private def report_error(status : Int32, error : String) : Nil
      @config.on_error.try(&.call(status, error))
    end
  end
end
