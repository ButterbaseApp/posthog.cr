require "json"
require "log"

require "./errors"
require "./flag_hash"
require "./property_matcher"
require "./cohort_matcher"
require "./response"

module PostHog
  module FeatureFlags
    # Local feature flag evaluator for client-side evaluation.
    #
    # Evaluates feature flags locally using cached flag definitions,
    # avoiding network requests for low-latency decisions.
    #
    # The evaluator handles:
    # - Property matching (person and group properties)
    # - Cohort matching (AND/OR groups)
    # - Rollout percentages (consistent hashing)
    # - Multivariate flags (variant selection)
    # - Flag dependencies (with circular dependency detection)
    #
    # Example:
    # ```
    # evaluator = LocalEvaluator.new
    # evaluator.set_flag_definitions(flags, cohorts, group_type_mapping)
    #
    # result = evaluator.evaluate(
    #   "my-flag",
    #   distinct_id: "user-123",
    #   person_properties: {"email" => JSON::Any.new("user@example.com")}
    # )
    # ```
    class LocalEvaluator
      Log = ::Log.for(self)

      # Type aliases for clarity
      alias Properties = Hash(String, JSON::Any)
      alias GroupProperties = Hash(String, Hash(String, JSON::Any))
      alias FlagDefinitions = Hash(String, JSON::Any)
      alias CohortDefinitions = Hash(String, JSON::Any)
      alias GroupTypeMapping = Hash(String, String)

      # Result of a local evaluation
      struct EvaluationResult
        # The flag value (true, false, or variant string)
        getter value : FlagValue

        # Whether the evaluation was successful locally
        getter? locally_evaluated : Bool

        # Reason for the result (for debugging)
        getter reason : String?

        # Flag metadata (id, version)
        getter flag_id : Int64?
        getter flag_version : Int64?

        # Payload for the flag/variant
        getter payload : JSON::Any?

        def initialize(
          @value : FlagValue,
          @locally_evaluated : Bool = true,
          @reason : String? = nil,
          @flag_id : Int64? = nil,
          @flag_version : Int64? = nil,
          @payload : JSON::Any? = nil
        )
        end

        # Create a failed/inconclusive result
        def self.inconclusive(reason : String) : EvaluationResult
          new(nil, locally_evaluated: false, reason: reason)
        end
      end

      @flags_by_key : FlagDefinitions
      @cohorts : CohortDefinitions
      @group_type_mapping : GroupTypeMapping
      @mutex : Mutex

      def initialize
        @flags_by_key = FlagDefinitions.new
        @cohorts = CohortDefinitions.new
        @group_type_mapping = GroupTypeMapping.new
        @mutex = Mutex.new
      end

      # Set flag definitions from the local evaluation API response.
      #
      # This should be called by the Poller when new flag definitions are received.
      def set_flag_definitions(
        flags : Array(JSON::Any),
        cohorts : CohortDefinitions = CohortDefinitions.new,
        group_type_mapping : GroupTypeMapping = GroupTypeMapping.new
      ) : Nil
        @mutex.synchronize do
          @flags_by_key.clear
          flags.each do |flag|
            key = flag["key"]?.try(&.as_s?)
            @flags_by_key[key] = flag if key
          end
          @cohorts = cohorts
          @group_type_mapping = group_type_mapping
        end
      end

      # Check if flag definitions are loaded
      def has_flags? : Bool
        @mutex.synchronize do
          !@flags_by_key.empty?
        end
      end

      # Get all flag keys
      def flag_keys : Array(String)
        @mutex.synchronize do
          @flags_by_key.keys
        end
      end

      # Evaluate a single feature flag locally.
      #
      # Returns an EvaluationResult with the flag value and metadata.
      # If evaluation fails or requires server data, returns an inconclusive result.
      def evaluate(
        key : String,
        distinct_id : String,
        groups : Hash(String, String)? = nil,
        person_properties : Properties? = nil,
        group_properties : GroupProperties? = nil
      ) : EvaluationResult
        @mutex.synchronize do
          evaluate_internal(key, distinct_id, groups, person_properties, group_properties)
        end
      end

      # Evaluate all flags for a user locally.
      #
      # Returns a hash of flag keys to evaluation results.
      # Flags that fail local evaluation will have inconclusive results.
      def evaluate_all(
        distinct_id : String,
        groups : Hash(String, String)? = nil,
        person_properties : Properties? = nil,
        group_properties : GroupProperties? = nil
      ) : Hash(String, EvaluationResult)
        results = Hash(String, EvaluationResult).new

        @mutex.synchronize do
          @flags_by_key.each_key do |key|
            results[key] = evaluate_internal(key, distinct_id, groups, person_properties, group_properties)
          end
        end

        results
      end

      # Internal evaluation method (must be called with mutex held)
      private def evaluate_internal(
        key : String,
        distinct_id : String,
        groups : Hash(String, String)?,
        person_properties : Properties?,
        group_properties : GroupProperties?
      ) : EvaluationResult
        flag = @flags_by_key[key]?
        return EvaluationResult.inconclusive("Flag not found: #{key}") unless flag

        evaluate_flag(
          flag,
          distinct_id,
          groups || Hash(String, String).new,
          person_properties || Properties.new,
          group_properties || GroupProperties.new
        )
      rescue ex : RequiresServerEvaluation
        Log.debug { "Flag #{key} requires server evaluation: #{ex.reason}" }
        EvaluationResult.inconclusive(ex.reason)
      rescue ex : InconclusiveMatchError
        Log.debug { "Flag #{key} inconclusive: #{ex.reason}" }
        EvaluationResult.inconclusive(ex.reason)
      rescue ex : Exception
        Log.error(exception: ex) { "Error evaluating flag #{key}" }
        EvaluationResult.inconclusive("Evaluation error: #{ex.message}")
      end

      private def evaluate_flag(
        flag : JSON::Any,
        distinct_id : String,
        groups : Hash(String, String),
        person_properties : Properties,
        group_properties : GroupProperties
      ) : EvaluationResult
        flag_key = flag["key"]?.try(&.as_s?) || ""
        flag_id = flag["id"]?.try(&.as_i64?)
        flag_version = flag["version"]?.try(&.as_i64?)

        # Check if flag is active
        unless flag["active"]?.try(&.as_bool?) != false
          return EvaluationResult.new(
            false,
            locally_evaluated: true,
            reason: "Flag is inactive",
            flag_id: flag_id,
            flag_version: flag_version
          )
        end

        # Check for experience continuity (requires server)
        if flag["ensure_experience_continuity"]?.try(&.as_bool?)
          raise RequiresServerEvaluation.new("Flag has experience continuity enabled")
        end

        filters = flag["filters"]?
        return EvaluationResult.new(false, reason: "No filters") unless filters

        # Determine if this is a group-based flag
        aggregation_group_type_index = filters["aggregation_group_type_index"]?.try(&.as_i?)
        
        # Get the appropriate properties and distinct_id for evaluation
        eval_distinct_id, eval_properties = get_evaluation_context(
          distinct_id,
          groups,
          person_properties,
          group_properties,
          aggregation_group_type_index
        )

        # Evaluate the flag conditions
        evaluation_cache = Hash(String, FlagValue).new
        
        result = match_flag_conditions(
          flag,
          eval_distinct_id,
          eval_properties,
          evaluation_cache
        )

        # Get payload if flag is enabled
        payload = if result
                    get_flag_payload(flag, result)
                  else
                    nil
                  end

        EvaluationResult.new(
          result,
          locally_evaluated: true,
          reason: result ? "condition_match" : "no_condition_match",
          flag_id: flag_id,
          flag_version: flag_version,
          payload: payload
        )
      end

      # Get the appropriate evaluation context based on flag type
      private def get_evaluation_context(
        distinct_id : String,
        groups : Hash(String, String),
        person_properties : Properties,
        group_properties : GroupProperties,
        aggregation_group_type_index : Int32?
      ) : Tuple(String, Properties)
        if aggregation_group_type_index
          # Group-based flag
          group_type = @group_type_mapping[aggregation_group_type_index.to_s]?
          
          unless group_type
            raise InconclusiveMatchError.new(
              "Group type index #{aggregation_group_type_index} not found in mapping"
            )
          end

          group_key = groups[group_type]?
          unless group_key
            raise InconclusiveMatchError.new(
              "Group key not provided for group type: #{group_type}"
            )
          end

          # Use group properties
          props = group_properties[group_type]? || Properties.new
          {group_key, props}
        else
          # Person-based flag
          {distinct_id, person_properties}
        end
      end

      # Match flag conditions and return the result
      private def match_flag_conditions(
        flag : JSON::Any,
        distinct_id : String,
        properties : Properties,
        evaluation_cache : Hash(String, FlagValue)
      ) : FlagValue
        flag_key = flag["key"]?.try(&.as_s?) || ""
        filters = flag["filters"]?
        return false unless filters

        condition_groups = filters["groups"]?.try(&.as_a?) || [] of JSON::Any

        # Track if any condition was inconclusive
        is_inconclusive = false
        inconclusive_reason = ""

        condition_groups.each_with_index do |condition, index|
          begin
            if match_condition(condition, distinct_id, properties, flag_key, evaluation_cache)
              # Condition matched - check rollout percentage
              rollout = condition["rollout_percentage"]?.try(&.as_f?) ||
                        condition["rollout_percentage"]?.try(&.as_i?.try(&.to_f64))

              if rollout.nil? || FlagHash.in_rollout?(flag_key, distinct_id, rollout)
                # Get variant if multivariate
                variant = FlagHash.get_variant_from_filters(flag_key, distinct_id, filters)
                return variant || true
              end
            end
          rescue ex : RequiresServerEvaluation
            raise ex # Propagate immediately
          rescue ex : InconclusiveMatchError
            is_inconclusive = true
            inconclusive_reason = ex.reason
            # Continue to try other conditions
          end
        end

        # If all conditions were inconclusive, raise
        if is_inconclusive && condition_groups.size > 0
          raise InconclusiveMatchError.new(inconclusive_reason)
        end

        false
      end

      # Match a single condition group
      private def match_condition(
        condition : JSON::Any,
        distinct_id : String,
        properties : Properties,
        flag_key : String,
        evaluation_cache : Hash(String, FlagValue)
      ) : Bool
        condition_properties = condition["properties"]?.try(&.as_a?) || [] of JSON::Any

        # Empty conditions always match
        return true if condition_properties.empty?

        # All properties must match (AND logic within a condition)
        condition_properties.each do |prop|
          next unless prop.raw.is_a?(Hash)

          prop_hash = prop.as_h.transform_keys(&.as(String))
          prop_type = prop["type"]?.try(&.as_s?)

          matches = case prop_type
                    when "cohort"
                      match_cohort_property(prop_hash, properties, evaluation_cache, distinct_id)
                    when "flag"
                      match_flag_property(prop_hash, properties, evaluation_cache, distinct_id)
                    else
                      PropertyMatcher.match(prop_hash, properties)
                    end

          return false unless matches
        end

        true
      end

      # Match a cohort property
      private def match_cohort_property(
        property : Hash(String, JSON::Any),
        properties : Properties,
        evaluation_cache : Hash(String, FlagValue),
        distinct_id : String
      ) : Bool
        cohort_id = property["value"]?.try(&.as_s?) ||
                    property["value"]?.try(&.as_i64?.try(&.to_s))

        unless cohort_id
          raise InconclusiveMatchError.new("Cohort property missing 'value'")
        end

        unless @cohorts.has_key?(cohort_id)
          raise RequiresServerEvaluation.new(
            "Cohort #{cohort_id} not found - likely a static cohort"
          )
        end

        cohort_definition = @cohorts[cohort_id]
        
        CohortMatcher.match_property_group(
          cohort_definition,
          properties,
          @cohorts,
          @flags_by_key,
          evaluation_cache,
          distinct_id
        )
      end

      # Match a flag dependency property
      private def match_flag_property(
        property : Hash(String, JSON::Any),
        properties : Properties,
        evaluation_cache : Hash(String, FlagValue),
        distinct_id : String
      ) : Bool
        dep_flag_key = property["key"]?.try(&.as_s?)
        unless dep_flag_key
          raise InconclusiveMatchError.new("Flag property missing 'key'")
        end

        dependency_chain = property["dependency_chain"]?.try(&.as_a?.try(&.map(&.as_s)))

        # Empty dependency chain = circular dependency
        if dependency_chain && dependency_chain.empty?
          raise InconclusiveMatchError.new("Circular dependency detected: #{dep_flag_key}")
        end

        # Evaluate dependencies in chain order
        if dependency_chain
          dependency_chain.each do |chain_key|
            evaluate_dependency(chain_key, distinct_id, properties, evaluation_cache)
          end
        end

        # Now check the actual dependency value
        unless evaluation_cache.has_key?(dep_flag_key)
          evaluate_dependency(dep_flag_key, distinct_id, properties, evaluation_cache)
        end

        actual_value = evaluation_cache[dep_flag_key]?
        expected_value = property["value"]?
        operator = property["operator"]?.try(&.as_s?) || "flag_evaluates_to"

        unless operator == "flag_evaluates_to"
          raise InconclusiveMatchError.new("Invalid flag operator: #{operator}")
        end

        matches_dependency_value(expected_value, actual_value)
      end

      # Evaluate a dependency flag and cache the result
      private def evaluate_dependency(
        flag_key : String,
        distinct_id : String,
        properties : Properties,
        evaluation_cache : Hash(String, FlagValue)
      ) : Nil
        return if evaluation_cache.has_key?(flag_key)

        dep_flag = @flags_by_key[flag_key]?
        unless dep_flag
          evaluation_cache[flag_key] = nil
          raise InconclusiveMatchError.new("Dependency flag not found: #{flag_key}")
        end

        # Check if flag is active
        unless dep_flag["active"]?.try(&.as_bool?) != false
          evaluation_cache[flag_key] = false
          return
        end

        # Recursively evaluate the dependency
        result = match_flag_conditions(dep_flag, distinct_id, properties, evaluation_cache)
        evaluation_cache[flag_key] = result
      end

      # Check if actual value matches expected dependency value
      private def matches_dependency_value(
        expected_value : JSON::Any?,
        actual_value : FlagValue
      ) : Bool
        return false if expected_value.nil?

        case actual = actual_value
        when String
          if expected_value.as_bool?
            expected_value.as_bool
          elsif expected_str = expected_value.as_s?
            actual == expected_str
          else
            false
          end
        when Bool
          if expected_bool = expected_value.as_bool?
            actual == expected_bool
          else
            false
          end
        when Nil
          expected_value.as_bool? == false
        else
          false
        end
      end

      # Get the payload for a flag result
      private def get_flag_payload(flag : JSON::Any, result : FlagValue) : JSON::Any?
        filters = flag["filters"]?
        return nil unless filters

        payloads = filters["payloads"]?
        return nil unless payloads

        payload_key = case result
                      when String
                        result
                      when true
                        "true"
                      when false
                        "false"
                      else
                        nil
                      end

        return nil unless payload_key

        raw_payload = payloads[payload_key]?
        return nil unless raw_payload

        # Payload might be JSON-encoded string
        if str = raw_payload.as_s?
          begin
            JSON.parse(str)
          rescue
            raw_payload
          end
        else
          raw_payload
        end
      end
    end
  end
end
