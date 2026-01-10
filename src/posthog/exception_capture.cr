require "json"

module PostHog
  # Exception capture module for serializing exceptions into PostHog $exception events
  module ExceptionCapture
    extend self

    # Maximum number of stack frames to include
    MAX_FRAMES = 50

    # Number of context lines to include before and after the error line
    CONTEXT_LINES = 5

    # Represents a single stack frame in the exception
    struct StackFrame
      include JSON::Serializable

      # Filename (relative or basename)
      getter filename : String

      # Absolute path to the file
      @[JSON::Field(key: "abs_path")]
      getter abs_path : String?

      # Line number
      getter lineno : Int32?

      # Column number
      getter colno : Int32?

      # Function name
      getter function : String?

      # Whether this frame is in application code (vs stdlib/shards)
      @[JSON::Field(key: "in_app")]
      getter in_app : Bool

      # The actual line of code
      @[JSON::Field(key: "context_line")]
      getter context_line : String?

      # Lines before the error
      @[JSON::Field(key: "pre_context")]
      getter pre_context : Array(String)?

      # Lines after the error
      @[JSON::Field(key: "post_context")]
      getter post_context : Array(String)?

      def initialize(
        @filename : String,
        @abs_path : String? = nil,
        @lineno : Int32? = nil,
        @colno : Int32? = nil,
        @function : String? = nil,
        @in_app : Bool = false,
        @context_line : String? = nil,
        @pre_context : Array(String)? = nil,
        @post_context : Array(String)? = nil
      )
      end
    end

    # Represents an exception in the $exception_list
    struct ExceptionInfo
      include JSON::Serializable

      # Exception type (class name)
      getter type : String

      # Exception message
      getter value : String

      # Exception mechanism
      getter mechanism : Mechanism

      # Stack trace
      getter stacktrace : Stacktrace?

      def initialize(
        @type : String,
        @value : String,
        @mechanism : Mechanism = Mechanism.new,
        @stacktrace : Stacktrace? = nil
      )
      end
    end

    # Mechanism for how the exception was captured
    struct Mechanism
      include JSON::Serializable

      # Mechanism type (always "generic" for manual captures)
      getter type : String

      # Whether the exception was handled
      getter handled : Bool

      # Whether this is a synthetic exception
      getter synthetic : Bool

      def initialize(
        @type : String = "generic",
        @handled : Bool = true,
        @synthetic : Bool = false
      )
      end
    end

    # Stacktrace container
    struct Stacktrace
      include JSON::Serializable

      # Stack frames (most recent first)
      getter frames : Array(StackFrame)

      def initialize(@frames : Array(StackFrame) = [] of StackFrame)
      end
    end

    # Parse an exception into properties for a $exception event
    #
    # ```
    # begin
    #   risky_operation
    # rescue ex
    #   properties = ExceptionCapture.parse_exception(ex)
    # end
    # ```
    def parse_exception(exception : Exception, handled : Bool = true) : Hash(String, JSON::Any)
      exception_list = [build_exception_info(exception, handled)]

      properties = Hash(String, JSON::Any).new
      properties["$exception_list"] = JSON::Any.new(exception_list.map(&.to_json).map { |j| JSON.parse(j) })
      properties["$exception_type"] = JSON::Any.new(exception.class.name)
      properties["$exception_message"] = JSON::Any.new(exception.message || "")

      properties
    end

    # Parse a string message into properties for a $exception event (no backtrace)
    def parse_message(message : String) : Hash(String, JSON::Any)
      exception_list = [ExceptionInfo.new(
        type: "Error",
        value: message,
        mechanism: Mechanism.new(handled: true, synthetic: true)
      )]

      properties = Hash(String, JSON::Any).new
      properties["$exception_list"] = JSON::Any.new(exception_list.map(&.to_json).map { |j| JSON.parse(j) })
      properties["$exception_type"] = JSON::Any.new("Error")
      properties["$exception_message"] = JSON::Any.new(message)

      properties
    end

    # Build exception info from an Exception object
    private def build_exception_info(exception : Exception, handled : Bool) : ExceptionInfo
      ExceptionInfo.new(
        type: exception.class.name,
        value: exception.message || "",
        mechanism: Mechanism.new(handled: handled),
        stacktrace: parse_backtrace(exception.backtrace?)
      )
    end

    # Parse Crystal backtrace into Stacktrace
    #
    # Crystal backtrace format:
    # "path/to/file.cr:42:7 in 'method_name'"
    # "/usr/lib/crystal/src/fiber.cr:146:11 in 'run'"
    private def parse_backtrace(backtrace : Array(String)?) : Stacktrace?
      return nil if backtrace.nil? || backtrace.empty?

      # Limit frames and reverse (most recent first)
      frames = backtrace.first(MAX_FRAMES).reverse.compact_map do |line|
        parse_stack_frame(line)
      end

      Stacktrace.new(frames: frames)
    end

    # Parse a single backtrace line into a StackFrame
    #
    # Format: "path/to/file.cr:42:7 in 'method_name'"
    private def parse_stack_frame(line : String) : StackFrame?
      # Match: path:line:column in 'function'
      # or: path:line in 'function'
      if match = line.match(/^(.+?):(\d+)(?::(\d+))?(?: in '(.+?)')?/)
        file_path = match[1]
        lineno = match[2].to_i
        colno = match[3]?.try(&.to_i)
        function = match[4]?

        # Determine if in-app (not stdlib or shards)
        in_app = is_in_app?(file_path)

        # Extract context lines
        context = extract_context(file_path, lineno)

        StackFrame.new(
          filename: File.basename(file_path),
          abs_path: file_path,
          lineno: lineno,
          colno: colno,
          function: function,
          in_app: in_app,
          context_line: context[:context_line],
          pre_context: context[:pre_context],
          post_context: context[:post_context]
        )
      else
        # Fallback for unparseable lines
        StackFrame.new(
          filename: line,
          in_app: false
        )
      end
    end

    # Determine if a file path is application code (vs stdlib/shards)
    private def is_in_app?(path : String) : Bool
      # Not in app if it contains known stdlib/dependency paths
      return false if path.includes?("/crystal/src/")
      return false if path.includes?("/lib/")
      return false if path.includes?("/shards/")
      return false if path.includes?("/usr/")
      return false if path.includes?("/opt/")
      return false if path.starts_with?("<")

      true
    end

    # Extract context lines from source file
    private def extract_context(file_path : String, lineno : Int32) : NamedTuple(
      context_line: String?,
      pre_context: Array(String)?,
      post_context: Array(String)?
    )
      # Return nil if file doesn't exist
      return {context_line: nil, pre_context: nil, post_context: nil} unless File.exists?(file_path)

      begin
        lines = File.read_lines(file_path)
        total_lines = lines.size

        # Line numbers are 1-indexed
        line_index = lineno - 1
        return {context_line: nil, pre_context: nil, post_context: nil} if line_index < 0 || line_index >= total_lines

        context_line = lines[line_index]?

        # Get pre-context (up to CONTEXT_LINES before)
        pre_start = Math.max(0, line_index - CONTEXT_LINES)
        pre_context = if line_index > 0
                        lines[pre_start...line_index].to_a
                      else
                        nil
                      end

        # Get post-context (up to CONTEXT_LINES after)
        post_end = Math.min(total_lines, line_index + CONTEXT_LINES + 1)
        post_context = if line_index < total_lines - 1
                         lines[(line_index + 1)...post_end].to_a
                       else
                         nil
                       end

        {
          context_line: context_line,
          pre_context: pre_context.nil? || pre_context.empty? ? nil : pre_context,
          post_context: post_context.nil? || post_context.empty? ? nil : post_context,
        }
      rescue
        # Silently fail if file can't be read
        {context_line: nil, pre_context: nil, post_context: nil}
      end
    end
  end
end
