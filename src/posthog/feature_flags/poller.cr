require "http/client"
require "json"
require "log"

require "./local_evaluator"
require "./errors"

module PostHog
  module FeatureFlags
    # Background poller for fetching feature flag definitions.
    #
    # Polls the PostHog `/api/feature_flag/local_evaluation/` endpoint at
    # regular intervals to keep local flag definitions up to date.
    #
    # Features:
    # - Background fiber with configurable polling interval
    # - ETag support for efficient caching (304 Not Modified)
    # - Automatic retry on transient errors
    # - Graceful shutdown
    #
    # Example:
    # ```
    # evaluator = LocalEvaluator.new
    # poller = Poller.new(
    #   api_key: "phc_xxx",
    #   personal_api_key: "phx_xxx",
    #   host: "https://us.i.posthog.com",
    #   evaluator: evaluator,
    #   polling_interval: 30.seconds
    # )
    # poller.start
    #
    # # Later...
    # poller.stop
    # ```
    class Poller
      Log = ::Log.for(self)

      # Response from the local evaluation API
      struct LocalEvaluationResponse
        getter flags : Array(JSON::Any)
        getter cohorts : Hash(String, JSON::Any)
        getter group_type_mapping : Hash(String, String)
        getter etag : String?

        def initialize(
          @flags : Array(JSON::Any) = [] of JSON::Any,
          @cohorts : Hash(String, JSON::Any) = Hash(String, JSON::Any).new,
          @group_type_mapping : Hash(String, String) = Hash(String, String).new,
          @etag : String? = nil
        )
        end

        def self.from_json(json_string : String, etag : String? = nil) : LocalEvaluationResponse
          data = JSON.parse(json_string)

          flags = data["flags"]?.try(&.as_a?) || [] of JSON::Any

          cohorts = Hash(String, JSON::Any).new
          if cohorts_data = data["cohorts"]?
            if cohorts_data.raw.is_a?(Hash)
              cohorts_data.as_h.each do |k, v|
                cohorts[k.to_s] = v
              end
            end
          end

          group_type_mapping = Hash(String, String).new
          if mapping_data = data["group_type_mapping"]?
            if mapping_data.raw.is_a?(Hash)
              mapping_data.as_h.each do |k, v|
                if str = v.as_s?
                  group_type_mapping[k.to_s] = str
                end
              end
            end
          end

          new(flags, cohorts, group_type_mapping, etag)
        end

        def self.not_modified(etag : String?) : LocalEvaluationResponse
          new(etag: etag)
        end
      end

      @api_key : String
      @personal_api_key : String
      @host : String
      @evaluator : LocalEvaluator
      @polling_interval : Time::Span
      @request_timeout : Time::Span
      @skip_ssl_verification : Bool
      @on_error : Proc(Int32, String, Nil)?

      @running : Bool = false
      @fiber : Fiber?
      @http_client : HTTP::Client?
      @etag : String?
      @stop_channel : Channel(Nil)
      @mutex : Mutex

      def initialize(
        @api_key : String,
        @personal_api_key : String,
        @host : String,
        @evaluator : LocalEvaluator,
        @polling_interval : Time::Span = 30.seconds,
        @request_timeout : Time::Span = 10.seconds,
        @skip_ssl_verification : Bool = false,
        @on_error : Proc(Int32, String, Nil)? = nil
      )
        @etag = nil
        @stop_channel = Channel(Nil).new
        @mutex = Mutex.new
      end

      # Start the background polling fiber.
      #
      # Does nothing if already running.
      def start : Nil
        @mutex.synchronize do
          return if @running
          @running = true
          @stop_channel = Channel(Nil).new

          @fiber = spawn do
            run_loop
          end
        end

        # Perform initial fetch synchronously to ensure flags are available
        poll_once
      end

      # Stop the background polling fiber.
      #
      # Blocks until the fiber has stopped.
      def stop : Nil
        @mutex.synchronize do
          return unless @running
          @running = false

          begin
            @stop_channel.send(nil)
          rescue Channel::ClosedError
            # Already closed
          end
        end

        # Wait for fiber to finish
        while @mutex.synchronize { @fiber.try(&.dead?) == false }
          sleep(10.milliseconds)
        end

        @http_client.try(&.close)
        @http_client = nil
      end

      # Check if the poller is running.
      def running? : Bool
        @mutex.synchronize { @running }
      end

      # Force an immediate poll (useful for testing or manual refresh).
      def poll_once : Nil
        fetch_flags
      end

      # Get the current ETag value (for testing).
      def etag : String?
        @etag
      end

      private def run_loop : Nil
        loop do
          select
          when @stop_channel.receive?
            break
          when timeout(@polling_interval)
            fetch_flags
          end
        end
      rescue ex
        Log.error(exception: ex) { "Poller error" }
        @mutex.synchronize { @running = false }
      end

      private def fetch_flags : Nil
        begin
          response = make_request
          
          case response
          when LocalEvaluationResponse
            if response.flags.empty? && @etag == response.etag
              # 304 Not Modified - keep existing flags
              Log.debug { "Feature flags not modified (ETag match)" }
            else
              # Update evaluator with new flags
              @evaluator.set_flag_definitions(
                response.flags,
                response.cohorts,
                response.group_type_mapping
              )
              @etag = response.etag
              Log.debug { "Feature flags updated: #{response.flags.size} flags" }
            end
          end
        rescue ex : QuotaLimitedError
          Log.warn { "Feature flags quota limited" }
          report_error(402, "Quota limited")
        rescue ex : Socket::Error | IO::Error | OpenSSL::SSL::Error
          Log.warn { "Feature flags network error: #{ex.message}" }
          report_error(-1, ex.message || "Network error")
        rescue ex : IO::TimeoutError
          Log.warn { "Feature flags request timeout" }
          report_error(-1, "Request timeout")
        rescue ex : JSON::ParseException
          Log.warn { "Feature flags JSON parse error: #{ex.message}" }
          report_error(-1, "Invalid response")
        rescue ex : Exception
          Log.error(exception: ex) { "Feature flags fetch error" }
          report_error(-1, ex.message || "Unknown error")
        end
      end

      private def make_request : LocalEvaluationResponse
        client = get_http_client
        headers = build_headers

        url = "/api/feature_flag/local_evaluation/?token=#{@api_key}&send_cohorts"
        response = client.get(url, headers: headers)

        case response.status_code
        when 200
          response_etag = response.headers["ETag"]?
          LocalEvaluationResponse.from_json(response.body, response_etag)
        when 304
          # Not Modified - return empty response with existing etag
          LocalEvaluationResponse.not_modified(@etag)
        when 402
          raise QuotaLimitedError.new
        when 401, 403
          raise RequiresServerEvaluation.new("Authentication error: #{response.status_code}")
        else
          raise Exception.new("Request failed: #{response.status_code}")
        end
      end

      private def get_http_client : HTTP::Client
        @http_client ||= begin
          uri = URI.parse(@host.chomp("/"))

          tls_context = if @skip_ssl_verification && uri.scheme == "https"
                          ctx = OpenSSL::SSL::Context::Client.new
                          ctx.verify_mode = OpenSSL::SSL::VerifyMode::NONE
                          ctx
                        elsif uri.scheme == "https"
                          OpenSSL::SSL::Context::Client.new
                        else
                          nil
                        end

          client = HTTP::Client.new(uri, tls: tls_context)
          client.read_timeout = @request_timeout
          client.connect_timeout = @request_timeout
          client
        end
      end

      private def build_headers : HTTP::Headers
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{@personal_api_key}",
          "Content-Type"  => "application/json",
          "User-Agent"    => "posthog-crystal/#{PostHog::VERSION}",
          "Accept"        => "application/json",
        }

        if etag = @etag
          headers["If-None-Match"] = etag
        end

        headers
      end

      private def report_error(status : Int32, error : String) : Nil
        @on_error.try(&.call(status, error))
      end
    end
  end
end
