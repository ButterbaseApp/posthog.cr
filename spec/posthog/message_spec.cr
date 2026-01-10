require "../spec_helper"

describe PostHog::Message do
  describe "#initialize" do
    it "creates a message with all fields" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test_event",
        distinct_id: "user_123",
        timestamp: "2024-01-15T10:30:00.000Z",
        message_id: "msg_123",
        properties: props(key: "value")
      )

      message.type.should eq "capture"
      message.event.should eq "test_event"
      message.distinct_id.should eq "user_123"
      message.timestamp.should eq "2024-01-15T10:30:00.000Z"
      message.message_id.should eq "msg_123"
      message.properties["key"].as_s.should eq "value"
    end

    it "includes library metadata" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: Hash(String, JSON::Any).new
      )

      message.library.should eq "posthog-crystal"
      message.library_version.should eq PostHog::VERSION
    end
  end

  describe "#to_json" do
    it "serializes to valid JSON" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test_event",
        distinct_id: "user_123",
        timestamp: "2024-01-15T10:30:00.000Z",
        message_id: "msg_123",
        properties: props(color: "blue")
      )

      json = message.to_json
      parsed = JSON.parse(json)

      parsed["type"].as_s.should eq "capture"
      parsed["event"].as_s.should eq "test_event"
      parsed["distinct_id"].as_s.should eq "user_123"
      parsed["messageId"].as_s.should eq "msg_123"
      parsed["properties"]["color"].as_s.should eq "blue"
    end

    it "omits nil uuid" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: Hash(String, JSON::Any).new,
        uuid: nil
      )

      json = message.to_json
      parsed = JSON.parse(json)
      parsed["uuid"]?.should be_nil
    end

    it "includes uuid when present" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: Hash(String, JSON::Any).new,
        uuid: "550e8400-e29b-41d4-a716-446655440000"
      )

      json = message.to_json
      parsed = JSON.parse(json)
      parsed["uuid"].as_s.should eq "550e8400-e29b-41d4-a716-446655440000"
    end
  end

  describe "#byte_size" do
    it "returns the JSON byte size" do
      message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: Hash(String, JSON::Any).new
      )

      message.byte_size.should eq message.to_json.bytesize
    end
  end
end

describe PostHog::BatchAddResult do
  it "has Added, BatchFull, and MessageTooLarge values" do
    PostHog::BatchAddResult::Added.should be_a(PostHog::BatchAddResult)
    PostHog::BatchAddResult::BatchFull.should be_a(PostHog::BatchAddResult)
    PostHog::BatchAddResult::MessageTooLarge.should be_a(PostHog::BatchAddResult)
  end
end

describe PostHog::MessageBatch do
  describe "#add" do
    it "adds message to batch and returns Added" do
      batch = PostHog::MessageBatch.new
      message = create_test_message

      result = batch.add(message)

      result.should eq PostHog::BatchAddResult::Added
      result.added?.should be_true
      batch.size.should eq 1
    end

    it "returns BatchFull when batch is full by count" do
      batch = PostHog::MessageBatch.new(max_size: 2)

      batch.add(create_test_message).added?.should be_true
      batch.add(create_test_message).added?.should be_true
      batch.add(create_test_message).batch_full?.should be_true

      batch.size.should eq 2
    end

    it "returns MessageTooLarge for oversized message" do
      batch = PostHog::MessageBatch.new

      # Create a message with properties that exceed 32KB
      large_value = "x" * 40_000
      large_message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: props(large: large_value)
      )

      result = batch.add(large_message)
      result.should eq PostHog::BatchAddResult::MessageTooLarge
      result.message_too_large?.should be_true
      batch.size.should eq 0
    end

    it "returns BatchFull when batch exceeds byte limit" do
      # Create a small batch that fills up quickly
      batch = PostHog::MessageBatch.new(max_size: 100, max_bytes: 1000)

      # Add messages until we hit the byte limit
      count = 0
      loop do
        result = batch.add(create_test_message)
        break unless result.added?
        count += 1
        break if count > 50 # Safety limit
      end

      count.should be > 0
      count.should be < 100 # Should hit byte limit before count limit
    end
  end

  describe "#<< (deprecated)" do
    it "adds message to batch" do
      batch = PostHog::MessageBatch.new
      message = create_test_message

      result = batch << message

      result.should be_true
      batch.size.should eq 1
    end

    it "returns false when batch is full by count" do
      batch = PostHog::MessageBatch.new(max_size: 2)

      (batch << create_test_message).should be_true
      (batch << create_test_message).should be_true
      (batch << create_test_message).should be_false

      batch.size.should eq 2
    end

    it "returns false for oversized message" do
      batch = PostHog::MessageBatch.new

      # Create a message with properties that exceed 32KB
      large_value = "x" * 40_000
      large_message = PostHog::Message.new(
        type: "capture",
        event: "test",
        distinct_id: "user",
        timestamp: "2024-01-15T10:00:00.000Z",
        message_id: "msg",
        properties: props(large: large_value)
      )

      result = batch << large_message
      result.should be_false
      batch.size.should eq 0
    end
  end

  describe "#full?" do
    it "returns false when batch has capacity" do
      batch = PostHog::MessageBatch.new(max_size: 10)
      batch << create_test_message

      batch.full?.should be_false
    end

    it "returns true when batch reaches max size" do
      batch = PostHog::MessageBatch.new(max_size: 2)
      batch << create_test_message
      batch << create_test_message

      batch.full?.should be_true
    end
  end

  describe "#empty?" do
    it "returns true for new batch" do
      batch = PostHog::MessageBatch.new
      batch.empty?.should be_true
    end

    it "returns false after adding message" do
      batch = PostHog::MessageBatch.new
      batch << create_test_message

      batch.empty?.should be_false
    end
  end

  describe "#clear" do
    it "removes all messages" do
      batch = PostHog::MessageBatch.new
      batch << create_test_message
      batch << create_test_message

      batch.clear

      batch.empty?.should be_true
      batch.size.should eq 0
    end
  end

  describe "#to_json_payload" do
    it "creates valid JSON with api_key and batch" do
      batch = PostHog::MessageBatch.new
      batch << create_test_message

      payload = batch.to_json_payload("test_api_key")
      parsed = JSON.parse(payload)

      parsed["api_key"].as_s.should eq "test_api_key"
      parsed["batch"].as_a.size.should eq 1
    end
  end

  describe "#remaining_capacity" do
    it "returns remaining message slots" do
      batch = PostHog::MessageBatch.new(max_size: 10)

      batch.remaining_capacity.should eq 10

      batch.add(create_test_message)
      batch.remaining_capacity.should eq 9

      batch.add(create_test_message)
      batch.remaining_capacity.should eq 8
    end
  end

  describe "#remaining_bytes" do
    it "returns remaining byte capacity" do
      batch = PostHog::MessageBatch.new(max_bytes: 10000)

      initial = batch.remaining_bytes
      initial.should be > 0

      batch.add(create_test_message)
      batch.remaining_bytes.should be < initial
    end
  end

  describe "#payload_size" do
    it "returns total payload size" do
      batch = PostHog::MessageBatch.new
      batch.add(create_test_message)

      size = batch.payload_size("test_api_key")
      payload = batch.to_json_payload("test_api_key")

      size.should eq payload.bytesize
    end
  end

  describe "#max_size" do
    it "exposes max_size setting" do
      batch = PostHog::MessageBatch.new(max_size: 50)
      batch.max_size.should eq 50
    end
  end

  describe "#max_bytes" do
    it "exposes max_bytes setting" do
      batch = PostHog::MessageBatch.new(max_bytes: 100000)
      batch.max_bytes.should eq 100000
    end
  end
end

private def create_test_message : PostHog::Message
  PostHog::Message.new(
    type: "capture",
    event: "test_event",
    distinct_id: "user_123",
    timestamp: "2024-01-15T10:00:00.000Z",
    message_id: PostHog::Utils.generate_uuid,
    properties: props(test: "value")
  )
end
