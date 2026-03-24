# frozen_string_literal: true

require "active_support/notifications"

module MikrotikClient
  module Middleware
    # Middleware for structured request/response logging and instrumentation.
    #
    # Logs at INFO on every request with key=value pairs compatible with
    # log aggregators (Datadog, ELK, Loki, CloudWatch).
    # Logs at ERROR when an exception is raised, with full error context.
    # Publishes an ActiveSupport::Notifications event with complete payload.
    #
    # Keys filtered from debug body output: password, pass, passwd, secret, token, api_key, auth.
    class Logger < Base
      SENSITIVE_KEYS = %w[password pass passwd secret token api_key auth].freeze
      private_constant :SENSITIVE_KEYS

      # Executes the request, then logs and instruments the outcome.
      # The logging rescue ensures that logger failures never mask the original exception.
      #
      # @param env [Hash]
      # @return [Hash]
      def call(env)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        exception = nil

        @app.call(env)
      rescue => exception
        raise
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
        log_request(env, duration_ms, exception)
        publish_notification(env, duration_ms, exception)
      end

      private

      def log_request(env, duration_ms, exception)
        status  = exception ? "error" : "ok"
        level   = exception ? :error  : :info
        adapter = env[:settings]&.adapter_name
        host    = env[:settings]&.host

        line = "component=mikrotik_client event=request" \
               " method=#{env[:method]&.upcase}" \
               " path=#{env[:path]}" \
               " host=#{host}" \
               " adapter=#{adapter}" \
               " duration_ms=#{duration_ms}" \
               " status=#{status}"

        line += " error_class=#{exception.class} error=#{exception.message}" if exception

        MikrotikClient.logger.public_send(level) { line }

        MikrotikClient.logger.debug { "component=mikrotik_client event=request_detail params=#{sanitize(env[:params]).inspect}" }
        MikrotikClient.logger.debug { "component=mikrotik_client event=request_detail body=#{sanitize(env[:body]).inspect}" }
        MikrotikClient.logger.debug { "component=mikrotik_client event=request_detail response=#{env[:response].inspect}" } unless exception
      rescue => log_error
        MikrotikClient.logger.warn { "component=mikrotik_client event=logger_failure error=#{log_error.message}" } rescue nil
      end

      def publish_notification(env, duration_ms, exception)
        ActiveSupport::Notifications.instrument("request.mikrotik_client",
          method:        env[:method],
          path:          env[:path],
          host:          env[:settings]&.host,
          adapter:       env[:settings]&.adapter_name,
          duration_ms:    duration_ms,
          status:        exception ? :error : :ok,
          error_class:   exception&.class&.name,
          error_message: exception&.message
        )
      rescue => e
        MikrotikClient.logger.warn { "component=mikrotik_client event=notification_failure error=#{e.message}" } rescue nil
      end

      # Recursively returns a copy of the data with sensitive values replaced by [FILTERED].
      #
      # @param data [Object]
      # @return [Object]
      def sanitize(data)
        case data
        when Hash
          data.each_with_object({}) do |(k, v), h|
            h[k] = SENSITIVE_KEYS.any? { |s| k.to_s.downcase.include?(s) } ? "[FILTERED]" : sanitize(v)
          end
        when Array
          data.map { |v| sanitize(v) }
        else
          data
        end
      end
    end
  end
end
