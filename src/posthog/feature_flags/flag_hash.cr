require "openssl"

module PostHog
  module FeatureFlags
    # Consistent hashing utilities for feature flag rollouts and variant selection.
    #
    # Uses SHA1 hashing to deterministically assign users to rollout percentages
    # and multivariate experiment variants. The same user will always get the same
    # result for a given flag key.
    module FlagHash
      extend self

      # Scale factor for converting hash to float (2^60 - 1)
      # Using first 15 hex characters = 60 bits
      LONG_SCALE = 0xFFFFFFFFFFFFFFF_u64.to_f64

      # Variant lookup table entry for multivariate flags
      struct VariantRange
        getter value_min : Float64
        getter value_max : Float64
        getter key : String

        def initialize(@value_min : Float64, @value_max : Float64, @key : String)
        end

        # Check if a hash value falls within this variant's range
        def includes?(hash_value : Float64) : Bool
          hash_value >= @value_min && hash_value < @value_max
        end
      end

      # Compute a deterministic hash value between 0 and 1 for a given key and distinct_id.
      #
      # This is the core hashing function used for:
      # - Rollout percentage checks (hash < rollout_percentage / 100)
      # - Variant assignment (hash falls within variant's percentage range)
      #
      # The hash is deterministic: same inputs always produce the same output.
      # The distribution is uniform across [0, 1).
      #
      # Algorithm:
      # 1. Concatenate: "{key}.{distinct_id}{salt}"
      # 2. SHA1 hash the string
      # 3. Take first 15 hex characters (60 bits)
      # 4. Convert to integer and divide by LONG_SCALE
      #
      # Example:
      # ```
      # hash = FlagHash.compute("my-flag", "user-123")
      # if hash < 0.20  # 20% rollout
      #   # User is in the rollout
      # end
      # ```
      def compute(key : String, distinct_id : String, salt : String = "") : Float64
        hash_key = "#{key}.#{distinct_id}#{salt}"
        hex_digest = OpenSSL::Digest.new("SHA1").update(hash_key).final.hexstring
        hash_val = hex_digest[0, 15].to_u64(16)
        hash_val.to_f64 / LONG_SCALE
      end

      # Check if a user is within the rollout percentage for a flag.
      #
      # Returns true if the user's hash value is less than the rollout percentage.
      #
      # Example:
      # ```
      # if FlagHash.in_rollout?("my-flag", "user-123", 20.0)
      #   # User is in the 20% rollout
      # end
      # ```
      def in_rollout?(key : String, distinct_id : String, rollout_percentage : Float64) : Bool
        return true if rollout_percentage >= 100.0
        return false if rollout_percentage <= 0.0

        compute(key, distinct_id) < (rollout_percentage / 100.0)
      end

      # Build a variant lookup table from multivariate flag configuration.
      #
      # Takes an array of variants with rollout percentages and creates a lookup
      # table where each variant occupies a contiguous range of the [0, 1) space.
      #
      # Example:
      # ```
      # variants = [
      #   {"key" => "control", "rollout_percentage" => 50.0},
      #   {"key" => "test", "rollout_percentage" => 50.0}
      # ]
      # table = FlagHash.build_variant_lookup_table(variants)
      # # => [VariantRange(0.0, 0.5, "control"), VariantRange(0.5, 1.0, "test")]
      # ```
      def build_variant_lookup_table(variants : Array(JSON::Any)) : Array(VariantRange)
        lookup_table = [] of VariantRange
        value_min = 0.0

        variants.each do |variant|
          next unless variant.raw.is_a?(::Hash)

          key = variant["key"]?.try(&.as_s?)
          rollout = variant["rollout_percentage"]?.try(&.as_f?) ||
                    variant["rollout_percentage"]?.try(&.as_i?.try(&.to_f64))

          next unless key && rollout

          value_max = value_min + (rollout / 100.0)
          lookup_table << VariantRange.new(value_min, value_max, key)
          value_min = value_max
        end

        lookup_table
      end

      # Get the matching variant for a user based on consistent hashing.
      #
      # Uses the "variant" salt to ensure variant assignment is independent
      # from rollout percentage checks.
      #
      # Returns nil if no variant matches (shouldn't happen with valid config).
      #
      # Example:
      # ```
      # variant = FlagHash.get_matching_variant("my-flag", "user-123", lookup_table)
      # # => "control" or "test"
      # ```
      def get_matching_variant(
        key : String,
        distinct_id : String,
        lookup_table : Array(VariantRange)
      ) : String?
        return nil if lookup_table.empty?

        hash_value = compute(key, distinct_id, "variant")

        lookup_table.each do |variant|
          return variant.key if variant.includes?(hash_value)
        end

        # Fallback to last variant if hash is exactly 1.0 (shouldn't happen)
        lookup_table.last?.try(&.key)
      end

      # Get the matching variant directly from flag filters.
      #
      # Convenience method that builds the lookup table and finds the variant
      # in one call.
      #
      # Example:
      # ```
      # filters = flag["filters"]
      # variant = FlagHash.get_variant_from_filters("my-flag", "user-123", filters)
      # ```
      def get_variant_from_filters(
        key : String,
        distinct_id : String,
        filters : JSON::Any?
      ) : String?
        return nil unless filters

        multivariate = filters["multivariate"]?
        return nil unless multivariate

        variants = multivariate["variants"]?.try(&.as_a?)
        return nil unless variants && !variants.empty?

        lookup_table = build_variant_lookup_table(variants)
        get_matching_variant(key, distinct_id, lookup_table)
      end
    end
  end
end
