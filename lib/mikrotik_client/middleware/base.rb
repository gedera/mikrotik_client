# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Base class for all MikrotikClient middlewares.
    # Follows the Rack/Faraday pattern where each middleware calls the next one.
    #
    # @abstract
    class Base
      # @param app [#call] The next middleware or adapter in the stack.
      # @param options [Hash] Custom options for the middleware.
      def initialize(app, options = {})
        @app = app
        @options = options
      end

      # Executes the middleware logic and passes the env to the next one.
      #
      # @param env [Hash] The request environment.
      # @return [Hash] The processed environment.
      def call(env)
        # Override this method in subclasses
        @app.call(env)
      end
    end
  end
end
