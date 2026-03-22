# frozen_string_literal: true

module MikrotikClient
  # Centralized registry for transport adapters.
  # This avoids circular dependencies between Client and Registry.
  class AdapterRegistry
    @adapters = {}

    class << self
      # Registers an adapter class under a symbolic name.
      #
      # @param name [Symbol] The unique name for the adapter (:binary, :http).
      # @param klass [Class] The adapter class.
      # @return [void]
      def register(name, klass)
        @adapters[name.to_sym] = klass
      end

      # Looks up an adapter class by its name.
      #
      # @param name [Symbol]
      # @return [Class] The adapter class.
      # @raise [Error] If the adapter is not registered.
      def lookup(name)
        return @adapters[name.to_sym] if @adapters.key?(name.to_sym)

        # If not registered, try to trigger Zeitwerk autoloading by constant naming convention
        begin
          # e.g. :binary -> MikrotikClient::Adapter::Binary
          klass_name = name.to_s.split('_').map(&:capitalize).join
          # We use the full namespace to trigger Zeitwerk
          MikrotikClient::Adapter.const_get(klass_name)
        rescue NameError
          # Fallback to check if it was registered under an alias
        end

        @adapters[name.to_sym] || raise(Error, "Unknown adapter: #{name}. Registered: #{@adapters.keys.join(', ')}")
      end

      # Returns all registered adapter names.
      # @return [Array<Symbol>]
      def registered_names
        @adapters.keys
      end
    end
  end
end
