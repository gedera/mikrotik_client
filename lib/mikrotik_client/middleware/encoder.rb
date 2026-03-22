# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Middleware that handles character encoding conversion for the Binary API.
    # MikroTik ROS v6 (Binary) requires ISO-8859-1 encoding.
    # This middleware transparently converts outgoing strings to ISO-8859-1 and 
    # incoming strings back to UTF-8.
    #
    # @author Gabriel
    # @since 0.1.0
    class Encoder < Base
      # The encoding used by MikroTik Binary API
      MIKROTIK_ENCODING = "ISO-8859-1"
      # The standard encoding for Ruby/Rails apps
      RUBY_ENCODING = "UTF-8"

      # Processes the request and response encoding if the adapter is :binary.
      #
      # @param env [Hash] The request environment.
      # @return [Hash]
      def call(env)
        return @app.call(env) unless env[:settings].adapter_name == :binary

        # 1. Encode outgoing data (UTF-8 -> ISO-8859-1)
        env[:path]   = encode_recursive(env[:path])
        env[:body]   = encode_recursive(env[:body])
        env[:params] = encode_recursive(env[:params])

        @app.call(env)

        # 2. Decode incoming data (ISO-8859-1 -> UTF-8)
        env[:response] = decode_recursive(env[:response])

        env
      end

      private

      # Recursively encodes strings in Hashes, Arrays, or single values.
      #
      # @param value [Object]
      # @return [Object]
      def encode_recursive(value)
        case value
        when String
          value.encode(MIKROTIK_ENCODING, RUBY_ENCODING, invalid: :replace, undef: :replace)
        when Hash
          value.transform_values { |v| encode_recursive(v) }
        when Array
          value.map { |v| encode_recursive(v) }
        else
          value
        end
      end

      # Recursively decodes strings in Hashes, Arrays, or single values.
      #
      # @param value [Object]
      # @return [Object]
      def decode_recursive(value)
        case value
        when String
          # Force the encoding to ISO-8859-1 first to ensure valid conversion to UTF-8
          value.force_encoding(MIKROTIK_ENCODING).encode(RUBY_ENCODING, invalid: :replace, undef: :replace)
        when Hash
          value.transform_values { |v| decode_recursive(v) }
        when Array
          value.map { |v| decode_recursive(v) }
        else
          value
        end
      end
    end
  end
end
