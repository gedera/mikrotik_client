# frozen_string_literal: true

module MikrotikClient
  # Shared transformation logic for MikroTik response data.
  # Used by Middleware::Transformer (batch) and Adapter::Binary (per-record streaming).
  #
  # Converts kebab-case keys to snake_case symbols, casts booleans, integers and floats.
  module DataTransformer
    module_function

    # Recursively transforms a MikroTik response value into idiomatic Ruby.
    #
    # @param value [Object]
    # @return [Object]
    def transform(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), hash|
          hash[transform_key(k)] = transform(v)
        end
      when Array
        value.map { |v| transform(v) }
      when String
        cast_value(value)
      else
        value
      end
    end

    # Converts a MikroTik key to a snake_case symbol.
    # ".id" => :id, "mac-address" => :mac_address
    #
    # @param key [String]
    # @return [Symbol]
    def transform_key(key)
      key.to_s.sub(/^\./, "").gsub("-", "_").to_sym
    rescue StandardError
      key
    end

    # Casts a string to a more specific Ruby type.
    #
    # @param value [String]
    # @return [Object]
    def cast_value(value)
      case value
      when "true", "yes"       then true
      when "false", "no"       then false
      when /^-?\d+$/           then value.to_i
      when /^-?\d+\.\d+$/      then value.to_f
      else value
      end
    end
  end
end
