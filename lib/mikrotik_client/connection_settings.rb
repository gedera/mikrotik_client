# frozen_string_literal: true

module MikrotikClient
  # Holds connection settings and handles adapter selection.
  #
  # @attr [String] host The MikroTik host IP or domain.
  # @attr [Integer] port The port number (default: 8728 for API, 443 for REST).
  # @attr [String] user The username for authentication.
  # @attr [String] pass The password for authentication.
  # @attr [Symbol] adapter_name The adapter type (:mtik, :rest).
  # @attr [Hash] adapter_options Additional options for the adapter.
  class ConnectionSettings
    attr_accessor :host, :port, :user, :pass, :adapter_name, :adapter_options

    def initialize
      @adapter_name = :mtik
      @adapter_options = {}
      @port = 8728
    end

    # Set the adapter for the connection.
    #
    # @param name [Symbol] Adapter name (:mtik, :rest).
    # @param options [Hash] Optional adapter-specific configuration.
    # @return [void]
    def adapter(name, **options)
      @adapter_name = name
      @adapter_options = options
    end

    # Internal key used to identify a specific MikroTik connection in the pool.
    #
    # @return [String] A unique connection key.
    def connection_key
      "#{user}@#{host}:#{port}"
    end

    # Validates that all required settings are present and valid.
    # Raises ArgumentError with a descriptive message if any are missing or invalid.
    #
    # @raise [ArgumentError]
    # @return [void]
    def validate!
      errors = []
      errors << "host is required" if host.nil? || host.to_s.strip.empty?
      errors << "user is required" if user.nil? || user.to_s.strip.empty?
      errors << "port must be an integer between 1 and 65535" unless port.is_a?(Integer) && port.between?(1, 65_535)
      raise ArgumentError, "Invalid connection settings: #{errors.join(', ')}" if errors.any?
    end
  end
end
