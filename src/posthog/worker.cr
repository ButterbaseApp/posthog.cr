require "log"

module PostHog
  # Background fiber worker that consumes messages from the queue
  # and sends them to PostHog in batches
  class Worker
    Log = ::Log.for(self)

    # Control message types for the worker
    enum Control
      Flush
      Shutdown
    end

    @running : Bool = false
    @fiber : Fiber?
    @requesting : Bool = false
    @on_message_processed : Proc(Nil)?

    def initialize(
      @config : Config,
      @transport : Transport,
      @message_channel : Channel(Message),
      @control_channel : Channel(Control),
      @on_message_processed : Proc(Nil)? = nil
    )
    end

    # Start the worker fiber
    def start : Nil
      return if @running
      @running = true

      @fiber = spawn do
        run_loop
      end
    end

    # Check if the worker is currently processing a request
    def requesting? : Bool
      @requesting
    end

    # Check if the worker is running
    def running? : Bool
      @running
    end

    private def run_loop : Nil
      batch = MessageBatch.new(@config.batch_size, Defaults::MAX_BATCH_BYTES)

      loop do
        # Try to receive from either channel
        select
        when message = @message_channel.receive?
          break if message.nil? # Channel closed

          # Signal that we've consumed a message from the queue
          @on_message_processed.try(&.call)

          unless batch << message
            # Batch is full or message too large, send current batch first
            if batch.full?
              send_batch(batch)
              batch.clear
              # Try adding message again
              unless batch << message
                # Message itself is too large
                Log.warn { "Message too large, dropping (#{message.byte_size} bytes)" }
                report_error(-1, "Message too large: #{message.byte_size} bytes")
              end
            else
              # Message is too large on its own
              Log.warn { "Message too large, dropping (#{message.byte_size} bytes)" }
              report_error(-1, "Message too large: #{message.byte_size} bytes")
            end
          end

          # Check if batch is full after adding
          if batch.full?
            send_batch(batch)
            batch.clear
          end

        when control = @control_channel.receive?
          break if control.nil? # Channel closed

          case control
          when Control::Flush
            # Drain remaining messages and send
            drain_and_send(batch)
            batch.clear
          when Control::Shutdown
            # Drain, send, and exit
            drain_and_send(batch)
            batch.clear
            @running = false
            break
          end
        end
      end

      # Final cleanup - send any remaining messages
      send_batch(batch) unless batch.empty?
      @running = false
    rescue ex
      Log.error(exception: ex) { "Worker error" }
      @running = false
    end

    private def drain_and_send(batch : MessageBatch) : Nil
      # Drain any remaining messages from the channel
      loop do
        select
        when message = @message_channel.receive?
          break if message.nil?

          # Signal that we've consumed a message from the queue
          @on_message_processed.try(&.call)

          unless batch << message
            if batch.full?
              send_batch(batch)
              batch.clear
              batch << message
            end
          end
        else
          # No more messages
          break
        end
      end

      # Send final batch
      send_batch(batch) unless batch.empty?
    end

    private def send_batch(batch : MessageBatch) : Nil
      return if batch.empty?

      @requesting = true
      begin
        response = @transport.send(@config.api_key, batch)

        unless response.success?
          Log.warn { "Failed to send batch: status=#{response.status}" }
          report_error(response.status, response.error || "HTTP #{response.status}")
        end
      ensure
        @requesting = false
      end
    end

    private def report_error(status : Int32, error : String) : Nil
      @config.on_error.try(&.call(status, error))
    end
  end
end
