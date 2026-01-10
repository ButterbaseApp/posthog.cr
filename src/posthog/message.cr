require "json"

module PostHog
  # Represents a message to be sent to PostHog
  struct Message
    include JSON::Serializable

    # Message type (capture, identify, alias, etc.)
    getter type : String

    # The event name (for capture) or special event like $identify
    getter event : String

    # Unique ID for this user
    @[JSON::Field(key: "distinct_id")]
    getter distinct_id : String

    # ISO8601 timestamp
    getter timestamp : String

    # Unique message ID for deduplication
    @[JSON::Field(key: "messageId")]
    getter message_id : String

    # Event properties
    getter properties : Hash(String, JSON::Any)

    # Optional: $set for identify
    @[JSON::Field(key: "$set", emit_null: false)]
    getter set_properties : Hash(String, JSON::Any)?

    # Library metadata
    getter library : String

    # Library version
    getter library_version : String

    # Optional UUID for capture events
    @[JSON::Field(emit_null: false)]
    getter uuid : String?

    def initialize(
      @type : String,
      @event : String,
      @distinct_id : String,
      @timestamp : String,
      @message_id : String,
      @properties : Hash(String, JSON::Any),
      @library : String = "posthog-crystal",
      @library_version : String = VERSION,
      @set_properties : Hash(String, JSON::Any)? = nil,
      @uuid : String? = nil
    )
    end

    # Calculate the JSON byte size of this message
    def byte_size : Int32
      to_json.bytesize.to_i32
    end
  end

  # Result of attempting to add a message to a batch
  enum BatchAddResult
    # Message was added successfully
    Added
    # Batch is full (by count or byte size), message not added
    BatchFull
    # Individual message exceeds max message size
    MessageTooLarge
  end

  # A batch of messages ready to be sent
  #
  # Enforces PostHog API limits:
  # - Max 32KB per message
  # - Max 500KB per batch
  # - Max 100 messages per batch (configurable)
  #
  # Example:
  # ```
  # batch = MessageBatch.new
  # case batch.add(message)
  # when .added?
  #   puts "Message queued"
  # when .batch_full?
  #   # Send current batch, then retry
  #   transport.send(api_key, batch)
  #   batch.clear
  #   batch.add(message)
  # when .message_too_large?
  #   puts "Message dropped: exceeds 32KB limit"
  # end
  # ```
  class MessageBatch
    getter messages : Array(Message)
    getter json_size : Int32
    getter max_size : Int32
    getter max_bytes : Int32

    def initialize(@max_size : Int32 = Defaults::BATCH_SIZE, @max_bytes : Int32 = Defaults::MAX_BATCH_BYTES)
      @messages = [] of Message
      @json_size = 2 # Account for [] brackets
    end

    # Try to add a message to the batch
    # Returns true if added, false if batch is full or message too large
    #
    # @deprecated Use `add` instead for more detailed result information
    def <<(message : Message) : Bool
      add(message).added?
    end

    # Add a message to the batch with detailed result
    #
    # Returns BatchAddResult indicating success or reason for failure.
    def add(message : Message) : BatchAddResult
      message_json = message.to_json
      message_bytes = message_json.bytesize

      # Check if single message exceeds limit
      if message_bytes > Defaults::MAX_MESSAGE_BYTES
        return BatchAddResult::MessageTooLarge
      end

      # Account for comma separator if not first message
      separator_size = @messages.empty? ? 0 : 1
      new_size = @json_size + message_bytes + separator_size

      # Check if adding would exceed batch limits
      if @messages.size >= @max_size || new_size > @max_bytes
        return BatchAddResult::BatchFull
      end

      @messages << message
      @json_size = new_size
      BatchAddResult::Added
    end

    # Check if the batch is full
    def full? : Bool
      @messages.size >= @max_size || @json_size >= @max_bytes
    end

    # Check if the batch is empty
    def empty? : Bool
      @messages.empty?
    end

    # Number of messages in the batch
    def size : Int32
      @messages.size
    end

    # Remaining capacity in messages (by count)
    def remaining_capacity : Int32
      @max_size - @messages.size
    end

    # Remaining capacity in bytes (approximate)
    def remaining_bytes : Int32
      @max_bytes - @json_size
    end

    # Clear the batch
    def clear : Nil
      @messages.clear
      @json_size = 2
    end

    # Convert to JSON payload for API
    def to_json_payload(api_key : String) : String
      {
        "api_key" => api_key,
        "batch"   => @messages,
      }.to_json
    end

    # Total payload size in bytes (including api_key wrapper)
    def payload_size(api_key : String) : Int32
      to_json_payload(api_key).bytesize
    end
  end
end
