# frozen_string_literal: true

module MikrotikClient
  module Adapter
    # Mock adapter for testing purposes.
    # Allows stubbing responses without a real connection.
    class Test < Base
      attr_accessor :stubs

      def initialize(options = {})
        super
        @stubs = options[:stubs] || {}
      end

      def connect!
        self
      end

      def call(env)
        key = "#{env[:method].upcase} #{env[:path]}"
        
        if @stubs.key?(key)
          env[:response] = @stubs[key]
        else
          raise Error, "No stub found for #{key}"
        end
      end
    end
  end
end
