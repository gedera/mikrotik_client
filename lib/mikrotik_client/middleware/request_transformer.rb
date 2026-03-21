# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Middleware that transforms outgoing request data into MikroTik's expected format.
    # - Converts snake_case symbols/strings to kebab-case strings.
    # - Normalizes :id to ".id" for consistent communication with RouterOS.
    class RequestTransformer < Base
      def call(env)
        env[:body] = transform_recursive(env[:body]) if env[:body]
        env[:params] = transform_recursive(env[:params]) if env[:params]

        @app.call(env)
      end

      private

      def transform_recursive(value)
        case value
        when Hash
          value.each_with_object({}) do |(k, v), hash|
            key_str = k.to_s
            # Internal convention: id becomes .id for all MikroTik API protocols
            new_key = (key_str == "id" || key_str == ".id") ? ".id" : key_str.gsub("_", "-")
            hash[new_key] = transform_recursive(v)
          end
        when Array
          value.map { |v| transform_recursive(v) }
        else
          value
        end
      end
    end
  end
end
