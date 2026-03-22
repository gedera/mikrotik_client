# frozen_string_literal: true

require "active_support/notifications"

module MikrotikClient
  module Middleware
    # Middleware for logging requests and responses.
    # Uses ActiveSupport::Notifications for instrumentation and the global logger.
    #
    # @author Gabriel
    # @since 0.1.0
    class Logger < Base
      # Executes the request and logs its performance and details.
      #
      # @param env [Hash]
      # @return [Hash]
      def call(env)
        start_time = Time.now
        
        ActiveSupport::Notifications.instrument("request.mikrotik_client", 
          host: env[:settings].host,
          path: env[:path],
          method: env[:method]
        ) do
          @app.call(env)
        end
      ensure
        duration = (Time.now - start_time) * 1000
        log_request(env, duration)
      end

      private

      # Logs the request details using the global logger.
      #
      # @param env [Hash]
      # @param duration [Float] Execution time in milliseconds.
      def log_request(env, duration)
        msg = "[MikrotikClient] #{env[:method].upcase} #{env[:path]} " \
              "(#{duration.round(2)}ms) - Host: #{env[:settings].host}"
        
        # Log basic info
        MikrotikClient.logger.info(msg)

        # Log detailed info in DEBUG mode
        if MikrotikClient.logger.debug?
          MikrotikClient.logger.debug "[MikrotikClient] Params: #{env[:params].inspect}"
          MikrotikClient.logger.debug "[MikrotikClient] Body: #{env[:body].inspect}"
          MikrotikClient.logger.debug "[MikrotikClient] Response: #{env[:response].inspect}"
        end
      end
    end
  end
end
