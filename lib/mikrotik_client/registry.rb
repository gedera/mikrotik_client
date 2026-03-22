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
    # @attr [Time] last_used_at The timestamp of the last time this pool was accessed.
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

    class << self
      # Returns the singleton instance of the registry.
      # @return [Registry]
      def instance
        @instance ||= new
      end

      # Yields a connection from the pool for the given configuration.
      # @param config [Configuration]
      # @yieldparam conn [Adapter::Base]
      # @return [Object]
      def with_connection(config, &block)
        instance.with_connection(config, &block)
      end
    end

    # Retrieves or creates a pool for the config and yields a connection.
    # @param config [Configuration]
    # @yieldparam conn [Adapter::Base]
    # @return [Object]
    def with_connection(config, &block)
      key = config.connection_key
      entry = mon_synchronize do
        @pools[key] ||= create_entry(config)
        @pools[key].last_used_at = Time.now
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
        now = Time.now
        @pools.delete_if do |key, entry|
          if (now - entry.last_used_at) > idle_timeout
            # Gracefully shutdown the pool and disconnect all its members
            entry.pool.shutdown { |adapter| adapter.disconnect! }
            true
          else
            false
          end
        end
      end
    end

    private

    # Creates a new PoolEntry with a configured ConnectionPool.
    # @param config [Configuration]
    # @return [PoolEntry]
    def create_entry(config)
      size = config.adapter_options[:pool_size] || MikrotikClient.config.pool_size
      timeout = config.adapter_options[:pool_timeout] || MikrotikClient.config.pool_timeout

      pool = ConnectionPool.new(size: size, timeout: timeout) do
        adapter_class = AdapterRegistry.lookup(config.adapter_name)
        adapter_class.new(config.adapter_options).tap do |adapter|
          adapter.instance_variable_set(:@configuration, config)
          adapter.connect!
        end
      end

      PoolEntry.new(pool, Time.now)
    end
  end
end
