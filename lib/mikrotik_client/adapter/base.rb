# frozen_string_literal: true

module MikrotikClient
  module Adapter
    # Base class for all MikroTik transport adapters.
    # Adapters are the final step in the middleware chain.
    #
    # @abstract
    class Base
      # @param settings [ConnectionSettings] The connection settings for this adapter.
      def initialize(settings)
        @settings = settings
      end

      # Performs the communication with the MikroTik device.
      #
      # @param env [Hash] The request environment.
      # @return [void]
      def call(env)
        # To be implemented by subclasses.
        # It must update env[:response].
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      # Establishes the physical connection.
      #
      # @return [self]
      def connect!
        raise NotImplementedError, "#{self.class} must implement #connect!"
      end

      # Closes the physical connection.
      #
      # @return [void]
      def disconnect!
        # Optional implementation
      end
    end
  end
end
