# frozen_string_literal: true

require "forwardable"

module MikrotikClient
  # User-facing client for interacting with MikroTik devices.
  #
  # @example Fetching IP addresses
  #   client = MikrotikClient.new do |conn|
  #     conn.host = "10.0.0.1"
  #     conn.user = "admin"
  #     conn.pass = "password"
  #     conn.use MikrotikClient::Middleware::Logger
  #     conn.adapter :binary
  #   end
  #
  #   addresses = client.get("/ip/address")
  class Client
    extend Forwardable

    # @return [ConnectionSettings] Connection settings.
    attr_reader :settings

    # @return [MiddlewareStack] The middleware builder.
    attr_reader :builder

    # @return [String, nil] Base URL or path.
    attr_accessor :url

    # @return [Hash] Default parameters for all requests.
    attr_accessor :params

    # Delegate configuration methods to the settings object
    def_delegators :@settings, :host, :host=, :port, :port=, :user, :user=, :pass, :pass=, :adapter

    # Initialize a new client with a configuration block.
    #
    # @param url [String, nil] Base URL or path.
    # @yield [self] The client instance.
    def initialize(url = nil)
      @url = url
      @params = {}
      @settings = ConnectionSettings.new
      @builder = MiddlewareStack.new
      yield(self) if block_given?
    end

    # Register a middleware to the stack.
    #
    # @param middleware_class [Class] The middleware class to use.
    # @param args [Array] Arguments to pass to the middleware initializer.
    # @return [void]
    def use(middleware_class, *args)
      @builder.use(middleware_class, *args)
    end

    # Performs a GET request (print in MikroTik API).
    #
    # @param path [String, nil] Command path (e.g., "/ip/address").
    # @param params [Hash, nil] Optional filters or arguments.
    # @yield [request] Optional block to configure the request.
    # @return [Array<Hash>, Hash] Command results.
    def get(path = nil, params = nil, &block)
      run_request(:get, path, nil, params, &block)
    end

    # Performs a POST request (add in MikroTik API).
    #
    # @param path [String, nil] Command path.
    # @param body [Hash, nil] Data to add.
    # @yield [request] Optional block to configure the request.
    # @return [Hash] Result of the operation.
    def post(path = nil, body = nil, &block)
      run_request(:post, path, body, nil, &block)
    end

    # Performs a PUT/PATCH request (set in MikroTik API).
    #
    # @param path [String, nil] Command path.
    # @param body [Hash, nil] Data to update.
    # @param params [Hash, nil] Optional filters to identify the target.
    # @yield [request] Optional block to configure the request.
    # @return [Hash] Result of the operation.
    def put(path = nil, body = nil, params = nil, &block)
      run_request(:put, path, body, params, &block)
    end

    # Performs a DELETE request (remove in MikroTik API).
    #
    # @param path [String, nil] Command path.
    # @param params [Hash, nil] Optional filters (like .id).
    # @yield [request] Optional block to configure the request.
    # @return [Hash] Result of the operation.
    def delete(path = nil, params = nil, &block)
      run_request(:delete, path, nil, params, &block)
    end

    private

    # Internal method to orquestrate the middleware pipeline.
    #
    # @param method [Symbol] HTTP-like method name.
    # @param path [String, nil] Command path.
    # @param body [Hash, nil] Request body.
    # @param params [Hash, nil] Request parameters.
    # @yield [request] Optional block to configure the request.
    # @return [Object] Final processed response.
    def run_request(method, path, body, params)
      request = Request.new(path || @url, (@params || {}).merge(params || {}), body)
      yield(request) if block_given?

      env = {
        method: method,
        path: request.path,
        body: request.body,
        params: request.params,
        type: request.type,
        on_data: request.on_data,
        settings: settings,
        response: nil
      }

      execute_stack(env)
    end

    # Builds and executes the middleware chain using the connection pool.
    #
    # @param env [Hash] The request environment.
    # @return [Object] The processed response data from the environment.
    def execute_stack(env)
      # We use the Registry to get a connected adapter from the pool
      Registry.with_connection(settings) do |adapter|
        # Build the chain using the builder
        app = @builder.build(adapter)

        # Start execution
        app.call(env)
      end

      # Return the processed response
      env[:response]
    end
  end
end
