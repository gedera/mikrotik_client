# frozen_string_literal: true

require "faraday"
require "json"
require "active_support/core_ext/hash/indifferent_access"

module MikrotikClient
  module Adapter
    # Adapter for MikroTik's REST API (ROS v7.1+).
    # Uses standard HTTP/JSON communication.
    class Http < Base
      AdapterRegistry.register :http, self
      AdapterRegistry.register :rest, self # Alias
      # Map our internal methods to MikroTik REST verbs
      METHOD_MAP = {
        get: :get,
        post: :put,    # add -> PUT
        put: :patch,   # set -> PATCH
        delete: :delete
      }.freeze

      # Executes a request over the REST API.
      def call(env)
        http_method = METHOD_MAP[env[:method]] || env[:method]
        params = (env[:params] || {}).with_indifferent_access
        
        # Look for ID in both common formats (.id or id)
        resource_id = params[".id"] || params[:id]
        
        response = @connection.send(http_method) do |req|
          path = env[:path].to_s.sub(/^\//, "")
          
          if [:get, :patch, :delete].include?(http_method) && resource_id
            req.url "rest/#{path}/#{resource_id}"
            req.params = params.except(".id", :id) if http_method == :get
          else
            req.url "rest/#{path}"
            req.params = params if http_method == :get
          end
          
          req.body = env[:body] if env[:body]
        end

        processed_response = parse_response(response, env)
        
        # Normalize: GET (print) should always return an Array for consistency
        if env[:method] == :get && processed_response.is_a?(Hash) && !processed_response.key?("_error_type")
          processed_response = [processed_response]
        end

        env[:response] = processed_response
      rescue Faraday::Error => e
        raise ConnectionError, "HTTP Connection failed: #{e.message}"
      end

      # Configures the Faraday connection.
      def connect!
        use_ssl = @settings.adapter_options.fetch(:ssl, true)
        scheme = use_ssl ? "https" : "http"
        base_url = "#{scheme}://#{@settings.host}:#{@settings.port}/"
        
        @connection = Faraday.new(url: base_url) do |f|
          f.request :authorization, :basic, @settings.user, @settings.pass
          f.request :json
          f.response :json
          
          f.options[:timeout] = MikrotikClient.config.read_timeout
          f.options[:open_timeout] = MikrotikClient.config.connect_timeout

          if use_ssl
            f.ssl[:verify] = @settings.adapter_options.fetch(:ssl_verify, true)
          end
          
          f.adapter Faraday.default_adapter
        end
        self
      end

      private

      def parse_response(response, env)
        case response.status
        when 200..299
          response.body
        when 404
          # Normalize: A 404 on a GET request is treated as an empty result set 
          # to match the Binary API behavior.
          env[:method] == :get ? [] : tagged_error(response)
        when 401
          raise AuthenticationError, "Invalid credentials for MikroTik REST API"
        else
          tagged_error(response)
        end
      end

      def tagged_error(response)
        error_body = response.body.is_a?(Hash) ? response.body : { "message" => response.body.to_s }
        error_body.merge("_error_type" => "!trap", "_http_status" => response.status)
      end
    end
  end
end
