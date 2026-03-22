# frozen_string_literal: true

require "zeitwerk"
require "active_support/all"
require_relative "mikrotik_client/version"

loader = Zeitwerk::Loader.for_gem
# Ensure generators are ignored by Zeitwerk to avoid constant mismatch warnings
loader.ignore(File.expand_path("generators", __dir__))
loader.setup

# @author Gabriel
# @since 0.1.0
module MikrotikClient
  # Base error class for all MikrotikClient errors
  class Error < StandardError; end

  # Connection and Auth errors
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class TimeoutError < Error; end

  # Command and Logic errors (4xx equivalent)
  class ClientError < Error; end
  class BadRequest < ClientError; end
  class NotFound < ClientError; end
  class PermissionError < ClientError; end
  class UnprocessableEntity < ClientError; end
  class Conflict < ClientError; end

  # Server errors (5xx equivalent)
  class ServerError < Error; end
  class InternalServerError < ServerError; end

  class << self
    # Global configuration object
    # @return [Config]
    def config
      @config ||= Config.new
    end

    # Global logger access
    # @return [Logger]
    def logger
      config.logger
    end

    # Block-based global configuration
    #
    # @example Configure MikrotikClient
    #   MikrotikClient.configure do |config|
    #     config.logger = Rails.logger
    #     config.log_level = Logger::DEBUG
    #     config.idle_timeout = 600
    #   end
    #
    # @yield [config] The global configuration object
    # @return [void]
    def configure
      yield(config) if block_given?
      config.apply_log_level!
    end

    # Temporary scoped configuration for a block of code.
    # Essential for multi-tenant Jobs or manual scripts.
    #
    # @example Sync multiple routers
    #   MikrotikClient.with_config(host: "10.0.0.1", user: "admin", pass: "...") do
    #     IpAddress.all
    #   end
    #
    # @param new_config [Hash] Configuration for the block.
    # @yield Block of code to execute under this configuration.
    # @return [Object] Result of the block.
    def with_config(new_config)
      old_config = Current.config
      Current.config = new_config
      yield
    ensure
      Current.config = old_config
    end

    # Helper method to create a new client instance
    #
    # @example Create a client with REST adapter
    #   client = MikrotikClient.new("/ip/address") do |conn|
    #     conn.adapter :http
    #   end
    #
    # @param url [String, nil] Base URL or path.
    # @yield [client] The client instance
    # @return [MikrotikClient::Client] A new client instance
    def new(url = nil, &block)
      Client.new(url, &block)
    end
  end
end
