module PostHog
  module FeatureFlags
    # Raised when a property cannot be matched definitively but other conditions
    # might still match. The evaluator should try the next condition.
    #
    # Examples:
    # - Property key missing from provided values
    # - Invalid regex pattern
    # - Invalid date format
    # - Missing property for cohort evaluation
    #
    # Unlike RequiresServerEvaluation, this error allows the evaluator to
    # continue trying other conditions before falling back to the server.
    class InconclusiveMatchError < Exception
      getter reason : String

      def initialize(@reason : String)
        super("Inconclusive match: #{@reason}")
      end
    end

    # Raised when feature flag evaluation requires server-side data that is not
    # available locally. This immediately triggers a fallback to the /flags API.
    #
    # Examples:
    # - Static cohort not in local cohort data
    # - Experience continuity enabled on flag
    # - Flag linked to early access feature
    # - Flag requires server-side person/group data
    #
    # Unlike InconclusiveMatchError, this error immediately propagates and
    # triggers an API fallback without trying other conditions.
    class RequiresServerEvaluation < Exception
      getter reason : String

      def initialize(@reason : String)
        super("Requires server evaluation: #{@reason}")
      end
    end

    # Raised when the local evaluation quota has been exceeded.
    # The SDK should fall back to remote evaluation.
    class QuotaLimitedError < Exception
      def initialize(message : String = "Feature flags quota limited")
        super(message)
      end
    end
  end
end
