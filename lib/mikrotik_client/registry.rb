# frozen_string_literal: true

require "connection_pool"
require "monitor"

module MikrotikClient
  # Manages a collection of connection pools for different MikroTik devices.
  # Uses a Reaper to automatically close and remove idle pools.
  #
  # @author Gabriel
  # @since 0.1.0
  class Registry
    include MonitorMixin

    # Represents a pool entry in the registry with its metadata.
    # @attr [ConnectionPool] pool The actual connection pool.
    # @attr [Float] last_used_at The monotonic timestamp of the last time this pool was accessed.
    PoolEntry = Struct.new(:pool, :last_used_at)

    # @return [Integer] Seconds of inactivity before a pool is pruned.
    attr_reader :idle_timeout

    # Initialize a new registry using global configuration.
    def initialize
      super()
      @pools = {}
      @idle_timeout = MikrotikClient.config.idle_timeout
      @reaper = Reaper.new(self)
      @reaper.start
    end

    INSTANCE_MUTEX = Mutex.new
    private_constant :INSTANCE_MUTEX

    class << self
      # Returns the singleton instance of the registry.
      # Thread-safe: uses a double-checked lock to avoid redundant synchronization.
      # @return [Registry]
      def instance
        return @instance if @instance
        INSTANCE_MUTEX.synchronize { @instance ||= new }
      end

      # Yields a connection from the pool for the given settings.
      # @param settings [ConnectionSettings]
      # @yieldparam conn [Adapter::Base]
      # @return [Object]
      def with_connection(settings, &block)
        instance.with_connection(settings, &block)
      end
    end

    # Retrieves or creates a pool for the settings and yields a connection.
    # @param settings [ConnectionSettings]
    # @yieldparam conn [Adapter::Base]
    # @return [Object]
    def with_connection(settings, &block)
      key = settings.connection_key
      entry = mon_synchronize do
        @pools[key] ||= create_entry(settings)
        @pools[key].last_used_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @pools[key]
      end

      entry.pool.with(&block)
    end

    # Removes pools that haven't been used within the idle_timeout.
    # This is called by the Reaper background thread.
    #
    # @return [void]
    def prune_idle_pools
      mon_synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @pools.delete_if do |key, entry|
          idle_for = (now - entry.last_used_at).round
          if idle_for > idle_timeout
            entry.pool.shutdown { |adapter| adapter.disconnect! }
            MikrotikClient.logger.info { "component=mikrotik_client event=pool_pruned key=#{key} idle_for_s=#{idle_for}" }
            true
          else
            false
          end
        end
      end
    end

    private

    # Creates a new PoolEntry with a configured ConnectionPool.
    # @param settings [ConnectionSettings]
    # @return [PoolEntry]
    def create_entry(settings)
      settings.validate!
      size    = settings.adapter_options[:pool_size]    || MikrotikClient.config.pool_size
      timeout = settings.adapter_options[:pool_timeout] || MikrotikClient.config.pool_timeout

      pool = ConnectionPool.new(size: size, timeout: timeout) do
        adapter_class = AdapterRegistry.lookup(settings.adapter_name)
        adapter_class.new(settings).tap(&:connect!)
      end

      MikrotikClient.logger.info do
        "component=mikrotik_client event=pool_created" \
        " key=#{settings.connection_key}" \
        " adapter=#{settings.adapter_name}" \
        " pool_size=#{size}"
      end

      PoolEntry.new(pool, Process.clock_gettime(Process::CLOCK_MONOTONIC))
    end
  end
end
