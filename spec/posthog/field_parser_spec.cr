require "../spec_helper"

describe PostHog::FieldParser do
  describe ".parse_for_capture" do
    it "creates a capture message with required fields" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event"
      )

      message.type.should eq "capture"
      message.event.should eq "test_event"
      message.distinct_id.should eq "user_123"
    end

    it "includes library metadata in properties" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event"
      )

      message.properties["$lib"].as_s.should eq "posthog-crystal"
      message.properties["$lib_version"].as_s.should eq PostHog::VERSION
    end

    it "generates a message_id" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event"
      )

      message.message_id.should match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end

    it "converts timestamp to ISO8601" do
      timestamp = Time.utc(2024, 1, 15, 10, 30, 0)
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        timestamp: timestamp
      )

      message.timestamp.should eq "2024-01-15T10:30:00.000Z"
    end

    it "includes custom properties" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        properties: props(color: "blue", count: 5)
      )

      message.properties["color"].as_s.should eq "blue"
      message.properties["count"].as_i.should eq 5
    end

    it "adds groups to properties" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        groups: {"company" => "acme"}
      )

      groups = message.properties["$groups"].as_h
      groups["company"].as_s.should eq "acme"
    end

    it "validates UUID if provided" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        uuid: "550e8400-e29b-41d4-a716-446655440000"
      )

      message.uuid.should eq "550e8400-e29b-41d4-a716-446655440000"
    end

    it "ignores invalid UUID" do
      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        uuid: "invalid-uuid"
      )

      message.uuid.should be_nil
    end

    it "adds feature variants to properties" do
      variants = {
        "flag1" => JSON::Any.new(true),
        "flag2" => JSON::Any.new("variant-a"),
        "flag3" => JSON::Any.new(false),
      }

      message = PostHog::FieldParser.parse_for_capture(
        distinct_id: "user_123",
        event: "test_event",
        feature_variants: variants
      )

      message.properties["$feature/flag1"].as_bool.should be_true
      message.properties["$feature/flag2"].as_s.should eq "variant-a"
      message.properties["$feature/flag3"].as_bool.should be_false

      active_flags = message.properties["$active_feature_flags"].as_a
      active_flags.size.should eq 2
      active_flags.map(&.as_s).should contain("flag1")
      active_flags.map(&.as_s).should contain("flag2")
      active_flags.map(&.as_s).should_not contain("flag3")
    end

    it "raises ValidationError for missing distinct_id" do
      expect_raises(PostHog::FieldParser::ValidationError, "distinct_id must be given") do
        PostHog::FieldParser.parse_for_capture(
          distinct_id: "",
          event: "test_event"
        )
      end
    end

    it "raises ValidationError for missing event" do
      expect_raises(PostHog::FieldParser::ValidationError, "event must be given") do
        PostHog::FieldParser.parse_for_capture(
          distinct_id: "user_123",
          event: ""
        )
      end
    end
  end

  describe ".parse_for_identify" do
    it "creates an identify message" do
      message = PostHog::FieldParser.parse_for_identify(
        distinct_id: "user_123",
        properties: props(email: "test@example.com")
      )

      message.type.should eq "identify"
      message.event.should eq "$identify"
      message.distinct_id.should eq "user_123"
    end

    it "includes properties in $set" do
      message = PostHog::FieldParser.parse_for_identify(
        distinct_id: "user_123",
        properties: props(email: "test@example.com", name: "Test User")
      )

      set_props = message.set_properties.not_nil!
      set_props["email"].as_s.should eq "test@example.com"
      set_props["name"].as_s.should eq "Test User"
    end

    it "raises ValidationError for missing distinct_id" do
      expect_raises(PostHog::FieldParser::ValidationError, "distinct_id must be given") do
        PostHog::FieldParser.parse_for_identify(distinct_id: "")
      end
    end
  end

  describe ".parse_for_alias" do
    it "creates an alias message" do
      message = PostHog::FieldParser.parse_for_alias(
        distinct_id: "user_123",
        alias_id: "anon_456"
      )

      message.type.should eq "alias"
      message.event.should eq "$create_alias"
      message.distinct_id.should eq "user_123"
    end

    it "includes distinct_id and alias in properties" do
      message = PostHog::FieldParser.parse_for_alias(
        distinct_id: "user_123",
        alias_id: "anon_456"
      )

      message.properties["distinct_id"].as_s.should eq "user_123"
      message.properties["alias"].as_s.should eq "anon_456"
    end

    it "raises ValidationError for missing distinct_id" do
      expect_raises(PostHog::FieldParser::ValidationError, "distinct_id must be given") do
        PostHog::FieldParser.parse_for_alias(distinct_id: "", alias_id: "anon")
      end
    end

    it "raises ValidationError for missing alias" do
      expect_raises(PostHog::FieldParser::ValidationError, "alias must be given") do
        PostHog::FieldParser.parse_for_alias(distinct_id: "user", alias_id: "")
      end
    end
  end

  describe ".parse_for_group_identify" do
    it "creates a group identify message" do
      message = PostHog::FieldParser.parse_for_group_identify(
        group_type: "company",
        group_key: "acme_inc"
      )

      message.type.should eq "group_identify"
      message.event.should eq "$groupidentify"
    end

    it "generates distinct_id from group type and key" do
      message = PostHog::FieldParser.parse_for_group_identify(
        group_type: "company",
        group_key: "acme_inc"
      )

      message.distinct_id.should eq "$company_acme_inc"
    end

    it "uses provided distinct_id if given" do
      message = PostHog::FieldParser.parse_for_group_identify(
        group_type: "company",
        group_key: "acme_inc",
        distinct_id: "custom_id"
      )

      message.distinct_id.should eq "custom_id"
    end

    it "includes group properties in $group_set" do
      message = PostHog::FieldParser.parse_for_group_identify(
        group_type: "company",
        group_key: "acme_inc",
        properties: props(name: "Acme Inc", employees: 50)
      )

      message.properties["$group_type"].as_s.should eq "company"
      message.properties["$group_key"].as_s.should eq "acme_inc"

      group_set = message.properties["$group_set"].as_h
      group_set["name"].as_s.should eq "Acme Inc"
      group_set["employees"].as_i.should eq 50
    end

    it "raises ValidationError for missing group_type" do
      expect_raises(PostHog::FieldParser::ValidationError, "group_type must be given") do
        PostHog::FieldParser.parse_for_group_identify(group_type: "", group_key: "acme")
      end
    end

    it "raises ValidationError for missing group_key" do
      expect_raises(PostHog::FieldParser::ValidationError, "group_key must be given") do
        PostHog::FieldParser.parse_for_group_identify(group_type: "company", group_key: "")
      end
    end
  end
end
