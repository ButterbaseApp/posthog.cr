require "json"

require "./errors"
require "./property_matcher"
require "./response"

module PostHog
  module FeatureFlags
    # Cohort matching engine for feature flag conditions.
    #
    # Handles AND/OR property groups with recursive evaluation.
    # Supports nested property groups for complex cohort definitions.
    #
    # Cohort structure example:
    # ```json
    # {
    #   "type": "AND",
    #   "values": [
    #     {"key": "email", "operator": "icontains", "value": "@example.com"},
    #     {
    #       "type": "OR",
    #       "values": [
    #         {"key": "plan", "operator": "exact", "value": "premium"},
    #         {"key": "plan", "operator": "exact", "value": "enterprise"}
    #       ]
    #     }
    #   ]
    # }
    # ```
    module CohortMatcher
      extend self

      # Type alias for cohort definitions keyed by cohort ID
      alias CohortDefinitions = Hash(String, JSON::Any)

      # Match a property group (AND/OR) against provided property values.
      #
      # This is the main entry point for cohort matching. It handles:
      # - Simple property conditions
      # - Nested AND/OR groups (recursive)
      # - Cohort references (looks up cohort definitions)
      # - Flag dependency properties (delegated to LocalEvaluator)
      #
      # Parameters:
      # - property_group: The property group definition (with "type" and "values")
      # - property_values: User/group properties to match against
      # - cohort_properties: Cohort definitions keyed by cohort ID
      # - flags_by_key: Feature flags keyed by flag key (for flag dependencies)
      # - evaluation_cache: Cache of already-evaluated flags (for dependencies)
      # - distinct_id: User identifier (for flag dependency evaluation)
      #
      # Returns true if the property group matches.
      #
      # Raises:
      # - InconclusiveMatchError if a property cannot be matched
      # - RequiresServerEvaluation if a cohort is not available locally
      def match_property_group(
        property_group : JSON::Any,
        property_values : PropertyMatcher::PropertyValues,
        cohort_properties : CohortDefinitions = CohortDefinitions.new,
        flags_by_key : Hash(String, JSON::Any)? = nil,
        evaluation_cache : Hash(String, FlagValue)? = nil,
        distinct_id : String? = nil
      ) : Bool
        # Handle non-hash values (shouldn't happen but be defensive)
        return true unless property_group.raw.is_a?(Hash)

        group_type = property_group["type"]?.try(&.as_s?) || "AND"
        values = property_group["values"]?.try(&.as_a?)

        # Empty groups are no-ops, always match
        return true if values.nil? || values.empty?

        # Check if values contains nested property groups or leaf properties
        first_value = values.first
        has_nested_groups = first_value["values"]? != nil

        if has_nested_groups
          # Recursively evaluate nested property groups
          match_nested_groups(
            values,
            group_type,
            property_values,
            cohort_properties,
            flags_by_key,
            evaluation_cache,
            distinct_id
          )
        else
          # Evaluate leaf properties
          match_leaf_properties(
            values,
            group_type,
            property_values,
            cohort_properties,
            flags_by_key,
            evaluation_cache,
            distinct_id
          )
        end
      end

      # Match nested property groups (recursive AND/OR evaluation)
      private def match_nested_groups(
        values : Array(JSON::Any),
        group_type : String,
        property_values : PropertyMatcher::PropertyValues,
        cohort_properties : CohortDefinitions,
        flags_by_key : Hash(String, JSON::Any)?,
        evaluation_cache : Hash(String, FlagValue)?,
        distinct_id : String?
      ) : Bool
        values.each do |nested_group|
          matches = match_property_group(
            nested_group,
            property_values,
            cohort_properties,
            flags_by_key,
            evaluation_cache,
            distinct_id
          )

          case group_type.upcase
          when "AND"
            return false unless matches
          when "OR"
            return true if matches
          end
        end

        # For AND: all matched (return true)
        # For OR: none matched (return false)
        group_type.upcase == "AND"
      end

      # Match leaf properties (actual property conditions)
      private def match_leaf_properties(
        values : Array(JSON::Any),
        group_type : String,
        property_values : PropertyMatcher::PropertyValues,
        cohort_properties : CohortDefinitions,
        flags_by_key : Hash(String, JSON::Any)?,
        evaluation_cache : Hash(String, FlagValue)?,
        distinct_id : String?
      ) : Bool
        values.each do |prop|
          next unless prop.raw.is_a?(Hash)

          prop_hash = prop.as_h.transform_keys(&.as(String))
          prop_type = prop["type"]?.try(&.as_s?)
          negation = prop["negation"]?.try(&.as_bool?) || false

          matches = case prop_type
                    when "cohort"
                      match_cohort(
                        prop_hash,
                        property_values,
                        cohort_properties,
                        flags_by_key,
                        evaluation_cache,
                        distinct_id
                      )
                    when "flag"
                      match_flag_dependency(
                        prop_hash,
                        flags_by_key,
                        evaluation_cache,
                        distinct_id,
                        property_values,
                        cohort_properties
                      )
                    else
                      # Regular property match
                      PropertyMatcher.match(prop_hash, property_values)
                    end

          # Apply negation
          matches = !matches if negation

          case group_type.upcase
          when "AND"
            return false unless matches
          when "OR"
            return true if matches
          end
        end

        # For AND: all matched (return true)
        # For OR: none matched (return false)
        group_type.upcase == "AND"
      end

      # Match a cohort property by looking up its definition
      private def match_cohort(
        property : Hash(String, JSON::Any),
        property_values : PropertyMatcher::PropertyValues,
        cohort_properties : CohortDefinitions,
        flags_by_key : Hash(String, JSON::Any)?,
        evaluation_cache : Hash(String, FlagValue)?,
        distinct_id : String?
      ) : Bool
        cohort_id = property["value"]?.try(&.as_s?) ||
                    property["value"]?.try(&.as_i64?.try(&.to_s))

        unless cohort_id
          raise InconclusiveMatchError.new("Cohort property missing 'value' (cohort ID)")
        end

        # Look up cohort definition
        unless cohort_properties.has_key?(cohort_id)
          # Static cohorts are not available locally - need server evaluation
          raise RequiresServerEvaluation.new(
            "Cohort #{cohort_id} not found in local cohorts - likely a static cohort"
          )
        end

        cohort_definition = cohort_properties[cohort_id]

        # Recursively match the cohort's property group
        match_property_group(
          cohort_definition,
          property_values,
          cohort_properties,
          flags_by_key,
          evaluation_cache,
          distinct_id
        )
      end

      # Match a flag dependency property
      #
      # Flag dependencies allow flags to depend on other flags' values.
      # Uses a dependency_chain to detect and handle circular dependencies.
      private def match_flag_dependency(
        property : Hash(String, JSON::Any),
        flags_by_key : Hash(String, JSON::Any)?,
        evaluation_cache : Hash(String, FlagValue)?,
        distinct_id : String?,
        property_values : PropertyMatcher::PropertyValues,
        cohort_properties : CohortDefinitions
      ) : Bool
        # Flag dependencies require the evaluator context
        unless flags_by_key && evaluation_cache && distinct_id
          raise InconclusiveMatchError.new(
            "Flag dependency evaluation requires flags_by_key, evaluation_cache, and distinct_id"
          )
        end

        flag_key = property["key"]?.try(&.as_s?)
        unless flag_key
          raise InconclusiveMatchError.new("Flag dependency missing 'key' field")
        end

        dependency_chain = property["dependency_chain"]?.try(&.as_a?.try(&.map(&.as_s)))

        # Empty dependency chain indicates circular dependency
        if dependency_chain && dependency_chain.empty?
          raise InconclusiveMatchError.new("Circular dependency detected for flag: #{flag_key}")
        end

        expected_value = property["value"]?
        operator = property["operator"]?.try(&.as_s?) || "flag_evaluates_to"

        unless operator == "flag_evaluates_to"
          raise InconclusiveMatchError.new("Invalid flag dependency operator: #{operator}")
        end

        # Evaluate dependency chain if present
        if dependency_chain
          dependency_chain.each do |dep_key|
            next if evaluation_cache.has_key?(dep_key)

            dep_flag = flags_by_key[dep_key]?
            unless dep_flag
              evaluation_cache[dep_key] = nil
              raise InconclusiveMatchError.new("Dependency flag not found: #{dep_key}")
            end

            # Check if flag is active
            unless dep_flag["active"]?.try(&.as_bool?) != false
              evaluation_cache[dep_key] = false
              next
            end

            # The actual evaluation will be done by LocalEvaluator
            # For now, raise an error that will be caught by LocalEvaluator
            raise InconclusiveMatchError.new(
              "Flag dependency requires LocalEvaluator: #{dep_key}"
            )
          end
        end

        # Get the actual flag value from cache
        actual_value = evaluation_cache[flag_key]?

        # Compare actual value with expected value
        matches_dependency_value(expected_value, actual_value)
      end

      # Check if actual flag value matches expected dependency value
      private def matches_dependency_value(
        expected_value : JSON::Any?,
        actual_value : FlagValue
      ) : Bool
        return false if expected_value.nil?

        case actual = actual_value
        when String
          # Variant string - check for exact match or boolean true
          if expected_value.as_bool?
            # Any non-empty variant matches boolean true
            expected_value.as_bool
          elsif expected_str = expected_value.as_s?
            # Case-sensitive variant comparison
            actual == expected_str
          else
            false
          end
        when Bool
          # Boolean case - must match exactly
          if expected_bool = expected_value.as_bool?
            actual == expected_bool
          else
            false
          end
        when Nil
          # Nil actual value - only matches if expected is false
          expected_value.as_bool? == false
        else
          false
        end
      end
    end
  end
end
