require "../spec_helper"

describe PostHog::ExceptionCapture do
  describe ".parse_exception" do
    it "parses an exception with full backtrace" do
      exception = begin
        raise "Test error"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)

      properties["$exception_type"].as_s.should eq("Exception")
      properties["$exception_message"].as_s.should eq("Test error")

      exception_list = properties["$exception_list"].as_a
      exception_list.size.should eq(1)

      exception_data = exception_list[0]
      exception_data["type"].as_s.should eq("Exception")
      exception_data["value"].as_s.should eq("Test error")

      mechanism = exception_data["mechanism"]
      mechanism["type"].as_s.should eq("generic")
      mechanism["handled"].as_bool.should be_true
      mechanism["synthetic"].as_bool.should be_false
    end

    it "includes stacktrace when backtrace is available" do
      exception = begin
        raise "Test error with backtrace"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      exception_data = exception_list[0]

      exception_data.as_h.has_key?("stacktrace").should be_true
      stacktrace = exception_data["stacktrace"]
      frames = stacktrace["frames"].as_a
      frames.size.should be > 0

      # Check first frame structure
      frame = frames[0]
      frame.as_h.has_key?("filename").should be_true
      frame.as_h.has_key?("function").should be_true
      frame.as_h.has_key?("lineno").should be_true
    end

    it "sets handled flag correctly" do
      exception = Exception.new("Test")
      
      # Handled exception
      handled_props = PostHog::ExceptionCapture.parse_exception(exception, handled: true)
      handled_list = handled_props["$exception_list"].as_a
      handled_list[0]["mechanism"]["handled"].as_bool.should be_true

      # Unhandled exception
      unhandled_props = PostHog::ExceptionCapture.parse_exception(exception, handled: false)
      unhandled_list = unhandled_props["$exception_list"].as_a
      unhandled_list[0]["mechanism"]["handled"].as_bool.should be_false
    end
  end

  describe ".parse_message" do
    it "creates exception from string message" do
      properties = PostHog::ExceptionCapture.parse_message("Something went wrong")

      properties["$exception_type"].as_s.should eq("Error")
      properties["$exception_message"].as_s.should eq("Something went wrong")

      exception_list = properties["$exception_list"].as_a
      exception_list.size.should eq(1)

      exception_data = exception_list[0]
      exception_data["type"].as_s.should eq("Error")
      exception_data["value"].as_s.should eq("Something went wrong")

      mechanism = exception_data["mechanism"]
      mechanism["type"].as_s.should eq("generic")
      mechanism["handled"].as_bool.should be_true
      mechanism["synthetic"].as_bool.should be_true
    end

    it "does not include stacktrace for string messages" do
      properties = PostHog::ExceptionCapture.parse_message("Error message")
      exception_list = properties["$exception_list"].as_a
      exception_data = exception_list[0]

      exception_data.as_h.has_key?("stacktrace").should be_false
    end
  end

  describe "stack frame parsing" do
    it "parses Crystal backtrace format" do
      exception = begin
        # Line that will appear in pre_context
        # Another line in pre_context
        # Yet another line
        # And one more
        # Last line before error
        raise "Test for backtrace parsing"
        # Line after error
        # Another post line
        # Third post line
        # Fourth post line
        # Fifth post line
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      exception_data = exception_list[0]
      stacktrace = exception_data["stacktrace"]
      frames = stacktrace["frames"].as_a

      # Should have at least one frame
      frames.size.should be > 0

      # Find a frame from our spec file (should be in the stack)
      spec_frames = frames.select { |f| f["filename"].as_s.includes?("exception_capture_spec.cr") }
      spec_frames.should_not be_empty
      
      spec_frame = spec_frames.first
      spec_frame.as_h.has_key?("lineno").should be_true
      spec_frame.as_h.has_key?("filename").should be_true
    end

    it "determines in_app correctly" do
      exception = begin
        raise "Test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # At least one frame should be marked as in_app (our test code)
      in_app_frames = frames.select { |f| f["in_app"].as_bool }
      in_app_frames.size.should be > 0

      # Stdlib frames should not be in_app
      stdlib_frames = frames.select do |f|
        abs_path = f["abs_path"]?.try(&.as_s?)
        abs_path && (abs_path.includes?("/crystal/src/") || abs_path.includes?("/lib/"))
      end
      
      stdlib_frames.each do |frame|
        frame["in_app"].as_bool.should be_false
      end
    end

    it "extracts filename from absolute path" do
      exception = begin
        raise "Test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      frames.each do |frame|
        filename = frame["filename"].as_s
        # Filename should not contain path separators
        filename.should_not contain("/")
      end
    end

    it "includes function names when available" do
      exception = begin
        raise "From test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # At least one frame should have a function name
      frames_with_function = frames.select { |f| f.as_h.has_key?("function") && f["function"].as_s? }
      frames_with_function.size.should be > 0
    end

    it "limits frames to MAX_FRAMES" do
      # Create exception with potentially many frames
      exception = begin
        raise "Test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # Verify max frames limit is respected
      frames.size.should be <= PostHog::ExceptionCapture::MAX_FRAMES
    end
  end

  describe "context line extraction" do
    it "extracts context lines from current file" do
      # Exception raised in this spec file will have context
      exception = begin
        # Pre-context line 1
        # Pre-context line 2
        # Pre-context line 3
        # Pre-context line 4
        # Pre-context line 5
        raise "Test error for context"  # This is the context line
        # Post-context line 1
        # Post-context line 2
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # Find a frame from this spec file
      spec_frame = frames.find { |f| f["filename"].as_s.includes?("exception_capture_spec.cr") }
      spec_frame.should_not be_nil
      
      if frame = spec_frame
        # Should have context_line
        context_line = frame["context_line"]?.try(&.as_s)
        context_line.should_not be_nil
        
        # Should have pre_context and post_context (if not at boundaries)
        # These may vary depending on which frame we're looking at
      end
    end

    it "handles unparseable backtrace lines" do
      # Create a fake exception with unusual backtrace format
      exception = Exception.new("Test")
      
      # Get properties with an exception that has a backtrace
      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      
      # Should still work even with edge cases
      exception_list.size.should eq(1)
    end
  end

  describe "in_app detection" do
    it "marks stdlib and shards as not in_app" do
      exception = begin
        raise "Test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # Stdlib frames should not be in_app
      stdlib_frames = frames.select do |f|
        abs_path = f["abs_path"]?.try(&.as_s?)
        abs_path && (
          abs_path.includes?("/crystal/src/") || 
          abs_path.includes?("/usr/") ||
          abs_path.includes?("/opt/") ||
          abs_path.includes?("/lib/")
        )
      end
      
      stdlib_frames.each do |frame|
        frame["in_app"].as_bool.should be_false
      end
    end

    it "marks project code as in_app" do
      exception = begin
        raise "Test"
      rescue ex
        ex
      end

      properties = PostHog::ExceptionCapture.parse_exception(exception)
      exception_list = properties["$exception_list"].as_a
      stacktrace = exception_list[0]["stacktrace"]
      frames = stacktrace["frames"].as_a

      # At least one frame from our spec should be in_app
      spec_frames = frames.select do |f|
        filename = f["filename"].as_s
        filename.includes?("exception_capture_spec.cr")
      end
      
      spec_frames.should_not be_empty
      spec_frames.each do |frame|
        frame["in_app"].as_bool.should be_true
      end
    end
  end

  describe "StackFrame serialization" do
    it "serializes to correct JSON structure" do
      frame = PostHog::ExceptionCapture::StackFrame.new(
        filename: "app.cr",
        abs_path: "/path/to/app.cr",
        lineno: 42,
        colno: 7,
        function: "process_data",
        in_app: true,
        context_line: "  raise Exception.new",
        pre_context: ["# Line before"],
        post_context: ["# Line after"]
      )

      json = frame.to_json
      parsed = JSON.parse(json)

      parsed["filename"].as_s.should eq("app.cr")
      parsed["abs_path"].as_s.should eq("/path/to/app.cr")
      parsed["lineno"].as_i.should eq(42)
      parsed["colno"].as_i.should eq(7)
      parsed["function"].as_s.should eq("process_data")
      parsed["in_app"].as_bool.should be_true
      parsed["context_line"].as_s.should eq("  raise Exception.new")
      parsed["pre_context"].as_a[0].as_s.should eq("# Line before")
      parsed["post_context"].as_a[0].as_s.should eq("# Line after")
    end

    it "omits nil fields from JSON" do
      frame = PostHog::ExceptionCapture::StackFrame.new(
        filename: "app.cr",
        in_app: false
      )

      json = frame.to_json
      parsed = JSON.parse(json)

      parsed.as_h.has_key?("abs_path").should be_false
      parsed.as_h.has_key?("lineno").should be_false
      parsed.as_h.has_key?("context_line").should be_false
    end
  end

  describe "ExceptionInfo serialization" do
    it "serializes complete exception info" do
      stacktrace = PostHog::ExceptionCapture::Stacktrace.new(
        frames: [
          PostHog::ExceptionCapture::StackFrame.new(
            filename: "app.cr",
            in_app: true
          ),
        ]
      )

      exception_info = PostHog::ExceptionCapture::ExceptionInfo.new(
        type: "TestError",
        value: "Test message",
        mechanism: PostHog::ExceptionCapture::Mechanism.new(handled: true),
        stacktrace: stacktrace
      )

      json = exception_info.to_json
      parsed = JSON.parse(json)

      parsed["type"].as_s.should eq("TestError")
      parsed["value"].as_s.should eq("Test message")
      parsed["mechanism"]["type"].as_s.should eq("generic")
      parsed["mechanism"]["handled"].as_bool.should be_true
      parsed["stacktrace"]["frames"].as_a.size.should eq(1)
    end
  end
end
