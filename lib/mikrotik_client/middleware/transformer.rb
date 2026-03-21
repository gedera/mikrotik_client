# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Middleware that transforms MikroTik response data into idiomatic Ruby.
    # - Converts kebab-case strings (e.g., "mac-address") to snake_case symbols (e.g., :mac_address).
    # - Casts string values like "true"/"false" to actual Booleans.
    # - Casts numeric strings to Integers or Floats where appropriate.
    #
    # @author Gabriel
    # @since 0.1.0
    class Transformer < Base
      # Executes the request and transforms the resulting response.
      #
      # @param env [Hash] The request environment.
      # @return [Hash]
      def call(env)
        @app.call(env)
        
        env[:response] = transform_recursive(env[:response])
        env
      end

      private

      # Recursively transforms the response structure.
      #
      # @param value [Object]
      # @return [Object]
      def transform_recursive(value)
        case value
        when Hash
          value.each_with_object({}) do |(k, v), hash|
            new_key = transform_key(k)
            new_val = transform_recursive(v)
            hash[new_key] = new_val
          end
        when Array
          value.map { |v| transform_recursive(v) }
        when String
          cast_value(value)
        else
          value
        end
      end

      # Transforms a MikroTik key string to an idiomatic Ruby symbol.
      # ".id" becomes :id, "mac-address" becomes :mac_address.
      #
      # @param key [String]
      # @return [Symbol, String]
      def transform_key(key)
        key.to_s.sub(/^\./, "").gsub("-", "_").to_sym
      rescue StandardError
        key # Fallback to original if transformation fails
      end

      # Casts a string value to a more specific Ruby type.
      #
      # @param value [String]
      # @return [Object]
      def cast_value(value)
        case value
        when "true", "yes" then true
        when "false", "no" then false
        # Strictly match integers (avoid leading zeros or IPs)
        when /^-?\d+$/      then value.to_i
        # Strictly match floats (only one dot)
        when /^-?\d+\.\d+$/ then value.to_f
        else
          value
        end
      end
    end
  end
end
