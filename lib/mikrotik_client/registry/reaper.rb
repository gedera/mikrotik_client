# frozen_string_literal: true

module MikrotikClient
  class Registry
    # Background worker responsible for cleaning up idle connection pools.
    # Runs in a separate thread and ensures thread-safety via the Registry's monitor.
    class Reaper
      # @param registry [Registry] The registry instance to prune.
      # @param interval [Integer] How often to run the pruning (seconds).
      def initialize(registry, interval: 60)
        @registry = registry
        @interval = interval
        @thread = nil
      end

      # Starts the reaper thread.
      # @return [Boolean] True if started, false if already running.
      def start
        return false if running?

        @stop = false
        @thread = Thread.new do
          Thread.current.name = "mikrotik_client_reaper"
          loop do
            sleep(@interval)
            break if @stop

            run_once
          rescue StandardError => e
            # Ensure the reaper thread doesn't die on single pool errors
            warn "[MikrotikClient::Reaper] background error: #{e.message}"
          end
        end
        true
      end

      # Checks if the reaper thread is alive.
      def running?
        @thread&.alive?
      end

      # Stops the reaper thread gracefully.
      # Signals the thread to exit and wakes it if sleeping, then waits up to 5s.
      def stop
        return unless running?

        @stop = true
        @thread.wakeup rescue nil  # Interrupt sleep so it exits promptly
        @thread.join(5)
        @thread = nil
      end

      # Manually triggers a pruning cycle.
      def run_once
        @registry.prune_idle_pools
      end
    end
  end
end
