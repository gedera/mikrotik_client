# frozen_string_literal: true

require "socket"
require "openssl"

module MikrotikClient
  module Adapter
    # Adapter for MikroTik's Binary API protocol.
    # Used for ROS v6 and legacy v7 communication.
    class Binary < Base
      AdapterRegistry.register :binary, self
      AdapterRegistry.register :mtik, self # Alias for backward compatibility
      # Map HTTP verbs to MikroTik API commands
      COMMAND_MAP = {
        get: "print",
        post: "add",
        put: "set",
        delete: "remove"
      }.freeze

      # Executes a command over the binary protocol.
      def call(env)
        command = build_command(env)
        @protocol.write_sentence(command)
        
        env[:response] = read_response(env)
      end

      # Connects to the MikroTik device and performs authentication.
      # Ensures the TCP socket is closed if SSL handshake or authentication fail.
      def connect!
        timeout = MikrotikClient.config.connect_timeout
        tcp_socket = Socket.tcp(@settings.host, @settings.port, connect_timeout: timeout)
        tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [MikrotikClient.config.read_timeout, 0].pack("l_2"))
        tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [MikrotikClient.config.read_timeout, 0].pack("l_2"))

        @socket = if @settings.adapter_options[:ssl]
          ssl_context = OpenSSL::SSL::SSLContext.new
          ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
          ssl_socket.connect
          ssl_socket
        else
          tcp_socket
        end

        @protocol = Protocol::Binary.new(@socket)
        authenticate!
        self
      rescue StandardError
        tcp_socket&.close rescue nil
        raise
      end

      # Closes the socket connection.
      def disconnect!
        @socket&.close
      end

      private

      # Handles the MikroTik login flow (Post-v6.43).
      def authenticate!
        @protocol.write_sentence(["/login"])
        response = @protocol.read_sentence
        
        if response.first == "!done"
          @protocol.write_sentence([
            "/login",
            "=name=#{@settings.user}",
            "=password=#{@settings.pass}"
          ])
          final_response = @protocol.read_sentence
          raise AuthenticationError, "Login failed" unless final_response.first == "!done"
        else
          raise AuthenticationError, "Legacy MD5 login not supported yet"
        end
      end

      # Builds the API command sentence.
      def build_command(env)
        cmd = ["#{env[:path]}/#{COMMAND_MAP[env[:method]]}"]

        # RequestTransformer already converted keys to kebab-case and .id.
        # Explicit .to_s guards against non-string keys/values reaching the socket.
        if env[:body]
          env[:body].each { |k, v| cmd << "=#{k}=#{v.to_s}" }
        end

        if env[:params]
          env[:params].each do |k, v|
            # Standard query for print (?) or identification (=)
            prefix = (env[:method] == :get) ? "?" : "="
            cmd << "#{prefix}#{k}=#{v.to_s}"
          end
        end

        cmd
      end

      # Reads the response sentences until !done.
      def read_response(env)
        results = []
        error = nil

        loop do
          sentence = @protocol.read_sentence
          type = sentence.shift

          case type
          when "!re"
            data = parse_sentence(sentence)
            # If no attributes were parsed, it might be a raw line (like in /export)
            data = sentence if data.empty? && env[:type] == :raw

            if env[:type] == :stream && env[:on_data]
              # Execute callback and check if user wants to stop
              break if env[:on_data].call(data) == :stop
            else
              results << data
            end
          when "!done"
            return error if error

            ret = parse_sentence(sentence)
            ret["id"] ||= ret["ret"] if ret["ret"]

            return results if env[:method] == :get || env[:type] == :stream
            return results.empty? ? ret : results
          when "!trap", "!fatal"
            error = parse_sentence(sentence)
            error["_error_type"] = type
            # In a stream, we might want to stop on error
            break if env[:type] == :stream
          end
        end
      end

      def parse_sentence(sentence)
        sentence.each_with_object({}) do |word, hash|
          if word =~ /^=([^=]+)=(.*)$/
            hash[$1] = $2
          elsif word =~ /^\.([^=]+)=(.*)$/
            hash[$1] = $2
          end
        end
      end
    end
  end
end
