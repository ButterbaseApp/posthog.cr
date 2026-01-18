require "json"

module PostHog
  # Parses and validates input fields, producing normalized Message objects
  module FieldParser
    extend self

    class ValidationError < Exception
    end

    # Type alias for properties hash
    alias Properties = Hash(String, JSON::Any)

    # Parse fields for a capture event
    def parse_for_capture(
      distinct_id : String,
      event : String,
      properties : Properties = Properties.new,
      groups : Hash(String, String)? = nil,
      timestamp : Time = Time.utc,
      uuid : String? = nil,
      feature_variants : Hash(String, JSON::Any)? = nil
    ) : Message
      validate_presence!(distinct_id, "distinct_id")
      validate_presence!(event, "event")

      props = build_base_properties(properties)

      # Add groups if provided
      if groups && !groups.empty?
        props["$groups"] = JSON::Any.new(groups.transform_values { |v| JSON::Any.new(v) })
      end

      # Add feature flag variants if provided
      if feature_variants && !feature_variants.empty?
        active_flags = [] of JSON::Any
        feature_variants.each do |key, value|
          props["$feature/#{key}"] = value
          # Only add to active flags if not false
          unless value.raw == false
            active_flags << JSON::Any.new(key)
          end
        end
        props["$active_feature_flags"] = JSON::Any.new(active_flags)
      end

      # Validate UUID if provided
      validated_uuid = if uuid && Utils.valid_uuid?(uuid)
                         uuid
                       elsif uuid
                         nil # Invalid UUID, ignore it
                       else
                         nil
                       end

      Message.new(
        type: "capture",
        event: event,
        distinct_id: distinct_id,
        timestamp: Utils.iso8601(timestamp),
        message_id: Utils.generate_uuid,
        properties: props,
        uuid: validated_uuid
      )
    end

    # Parse fields for an identify event
    def parse_for_identify(
      distinct_id : String,
      properties : Properties = Properties.new,
      timestamp : Time = Time.utc
    ) : Message
      validate_presence!(distinct_id, "distinct_id")

      props = build_base_properties(Properties.new)

      Message.new(
        type: "identify",
        event: "$identify",
        distinct_id: distinct_id,
        timestamp: Utils.iso8601(timestamp),
        message_id: Utils.generate_uuid,
        properties: props,
        set_properties: properties
      )
    end

    # Parse fields for an alias event
    def parse_for_alias(
      distinct_id : String,
      alias_id : String,
      timestamp : Time = Time.utc
    ) : Message
      validate_presence!(distinct_id, "distinct_id")
      validate_presence!(alias_id, "alias")

      props = build_base_properties(Properties.new)
      props["distinct_id"] = JSON::Any.new(distinct_id)
      props["alias"] = JSON::Any.new(alias_id)

      Message.new(
        type: "alias",
        event: "$create_alias",
        distinct_id: distinct_id,
        timestamp: Utils.iso8601(timestamp),
        message_id: Utils.generate_uuid,
        properties: props
      )
    end

    # Parse fields for a group identify event
    def parse_for_group_identify(
      group_type : String,
      group_key : String,
      properties : Properties = Properties.new,
      distinct_id : String? = nil,
      timestamp : Time = Time.utc
    ) : Message
      validate_presence!(group_type, "group_type")
      validate_presence!(group_key, "group_key")

      # Generate distinct_id if not provided
      actual_distinct_id = distinct_id || "$#{group_type}_#{group_key}"

      props = build_base_properties(Properties.new)
      props["$group_type"] = JSON::Any.new(group_type)
      props["$group_key"] = JSON::Any.new(group_key)
      props["$group_set"] = JSON::Any.new(properties.transform_values { |v| v })

      Message.new(
        type: "group_identify",
        event: "$groupidentify",
        distinct_id: actual_distinct_id,
        timestamp: Utils.iso8601(timestamp),
        message_id: Utils.generate_uuid,
        properties: props
      )
    end

    # Parse fields for an exception event
    def parse_for_exception(
      distinct_id : String,
      properties : Properties = Properties.new,
      timestamp : Time = Time.utc,
      ip : String? = nil
    ) : Message
      validate_presence!(distinct_id, "distinct_id")

      props = build_base_properties(properties)

      Message.new(
        type: "exception",
        event: "$exception",
        distinct_id: distinct_id,
        timestamp: Utils.iso8601(timestamp),
        message_id: Utils.generate_uuid,
        properties: props,
        ip: ip
      )
    end

    # Build base properties with library metadata
    private def build_base_properties(properties : Properties) : Properties
      props = Properties.new

      # Copy existing properties
      properties.each do |key, value|
        props[key] = value
      end

      # Add library metadata
      props["$lib"] = JSON::Any.new("posthog-crystal")
      props["$lib_version"] = JSON::Any.new(VERSION)

      props
    end

    # Validate that a value is present (not nil or empty string)
    private def validate_presence!(value : String?, field : String) : Nil
      if value.nil? || value.empty?
        raise ValidationError.new("#{field} must be given")
      end
    end
  end
end
