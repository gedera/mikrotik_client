# frozen_string_literal: true

require "connection_pool"
require "monitor"

module MikrotikClient
  # Manages a collection of connection pools for different MikroTik devices.
  # Implements a Reaper thread to automatically close and remove idle pools.
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
      setup_reaper
    end

    class << self
      # Returns the singleton instance of the registry.
      #
      # @return [Registry]
      def instance
        @instance ||= new
      end

      # Yields a connection from the pool for the given configuration.
      #
      # @param config [Configuration] The connection configuration.
      # @yieldparam conn [Adapter::Base] The active connection/adapter.
      # @return [Object] The result of the block.
      def with_connection(config, &block)
        instance.with_connection(config, &block)
      end
    end

    # Retrieves or creates a pool for the config and yields a connection.
    #
    # @param config [Configuration] The connection configuration.
    # @yieldparam conn [Adapter::Base] The active connection.
    # @return [Object] The result of the block.
    def with_connection(config, &block)
      key = config.connection_key
      entry = mon_synchronize do
        @pools[key] ||= create_entry(config)
        @pools[key].last_used_at = Time.now
        @pools[key]
      end

      entry.pool.with(&block)
    end

    private

    # Creates a new PoolEntry with a configured ConnectionPool.
    #
    # @param config [Configuration]
    # @return [PoolEntry]
    def create_entry(config)
      size = config.adapter_options[:pool_size] || MikrotikClient.config.pool_size
      timeout = config.adapter_options[:pool_timeout] || MikrotikClient.config.pool_timeout

      pool = ConnectionPool.new(size: size, timeout: timeout) do
        # Build the actual adapter and connect
        # We use AdapterRegistry to get the class without depending on Client
        adapter_class = AdapterRegistry.lookup(config.adapter_name)
        adapter_class.new(config.adapter_options).tap do |adapter|
          # We pass the full config to the adapter so it knows where to connect
          adapter.instance_variable_set(:@configuration, config)
          adapter.connect!
        end
      end

      PoolEntry.new(pool, Time.now)
    end

    # Starts a background thread to prune idle pools.
    #
    # @return [void]
    def setup_reaper
      Thread.new do
        loop do
          sleep 60 # Check every minute
          prune_idle_pools
        end
      end
    end

    # Removes pools that haven't been used within the idle_timeout.
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
    rescue StandardError => e
      # In a real Rails app, we'd log this to Rails.logger
      warn "[MikrotikClient::Registry] Reaper error: #{e.message}"
    end
  end
end
