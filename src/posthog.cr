require "json"
require "log"

require "./posthog/version"
require "./posthog/utils"
require "./posthog/config"
require "./posthog/message"
require "./posthog/field_parser"
require "./posthog/backoff_policy"
require "./posthog/response"
require "./posthog/transport"
require "./posthog/worker"
require "./posthog/feature_flags"
require "./posthog/exception_capture"
require "./posthog/client"

# PostHog Crystal SDK
#
# A Crystal-idiomatic SDK for PostHog analytics with async-first design.
#
# ## Quick Start
#
# ```crystal
# require "posthog"
#
# # Initialize the client
# posthog = PostHog::Client.new(
#   api_key: "phc_xxx",
#   host: "https://us.i.posthog.com"
# )
#
# # Capture an event
# posthog.capture(
#   distinct_id: "user_123",
#   event: "button_clicked",
#   properties: {"color" => JSON::Any.new("blue")}
# )
#
# # Identify a user
# posthog.identify(
#   distinct_id: "user_123",
#   properties: {"email" => JSON::Any.new("user@example.com")}
# )
#
# # Shutdown gracefully
# posthog.shutdown
# ```
#
# ## Configuration Options
#
# - `api_key` - Your PostHog project API key (required)
# - `host` - API host (default: "https://us.i.posthog.com")
# - `personal_api_key` - For local feature flag evaluation
# - `max_queue_size` - Max queued events before dropping (default: 10,000)
# - `batch_size` - Events per batch (default: 100)
# - `async` - Use background fiber (default: true)
# - `on_error` - Error callback
# - `before_send` - Modify/drop events before sending
#
module PostHog
  # Configure logging
  Log = ::Log.for(self)
end
