# frozen_string_literal: true

require "logger"

module MikrotikClient
  # Global configuration for the MikrotikClient gem.
  #
  # @attr [Logger] logger The logger instance to use (default: STDOUT).
  # @attr [Integer] log_level The logging level (default: Logger::INFO).
  # @attr [Integer] connect_timeout Seconds to wait for a connection (default: 5).
  # @attr [Integer] read_timeout Seconds to wait for a response (default: 10).
  # @attr [Integer] pool_size Default number of connections per pool (default: 5).
  # @attr [Integer] pool_timeout Seconds to wait for a connection from the pool (default: 5).
  # @attr [Integer] idle_timeout Seconds of inactivity before a pool is pruned (default: 300).
  class Config
    attr_accessor :logger, :log_level, :connect_timeout, :read_timeout, 
                  :pool_size, :pool_timeout, :idle_timeout

    def initialize
      @logger = Logger.new($stdout)
      @log_level = Logger::INFO
      @connect_timeout = 5
      @read_timeout = 10
      @pool_size = 5
      @pool_timeout = 5
      @idle_timeout = 300 # 5 minutes
    end

    # Applies the log level to the logger instance.
    def apply_log_level!
      @logger.level = @log_level if @logger
    end
  end
end
