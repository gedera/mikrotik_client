# frozen_string_literal: true

require "socket"
require "openssl"

module MikrotikClient
  module Adapter
    # Adapter for MikroTik's Binary API protocol.
    # Used for ROS v6 and legacy v7 communication.
    class Binary < Base
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
      def connect!
        timeout = MikrotikClient.config.connect_timeout
        @socket = Socket.tcp(@configuration.host, @configuration.port, connect_timeout: timeout)
        
        # Set read timeout on the socket
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [MikrotikClient.config.read_timeout, 0].pack("l_2"))
        @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [MikrotikClient.config.read_timeout, 0].pack("l_2"))

        # Enable SSL if configured
        if @configuration.adapter_options[:ssl]
          ssl_context = OpenSSL::SSL::SSLContext.new
          @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
          @socket.connect
        end

        @protocol = Protocol::Binary.new(@socket)
        authenticate!
        self
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
            "=name=#{@configuration.user}",
            "=password=#{@configuration.pass}"
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
        
        # RequestTransformer already converted keys to kebab-case and .id
        if env[:body]
          env[:body].each { |k, v| cmd << "=#{k}=#{v}" }
        end

        if env[:params]
          env[:params].each do |k, v|
            # Standard query for print (?) or identification (=)
            prefix = (env[:method] == :get) ? "?" : "="
            cmd << "#{prefix}#{k}=#{v}"
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
            results << parse_sentence(sentence)
          when "!done"
            return error if error

            ret = parse_sentence(sentence)
            ret["id"] ||= ret["ret"] if ret["ret"]
            
            return results if env[:method] == :get
            return results.empty? ? ret : results
          when "!trap", "!fatal"
            error = parse_sentence(sentence)
            error["_error_type"] = type
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
