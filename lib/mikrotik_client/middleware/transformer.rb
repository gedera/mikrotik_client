# frozen_string_literal: true

module MikrotikClient
  module Middleware
    # Middleware that transforms MikroTik response data into idiomatic Ruby.
    # Delegates to DataTransformer for the actual conversion logic.
    class Transformer < Base
      # Executes the request and transforms the resulting response.
      # Skipped entirely for :raw requests.
      #
      # @param env [Hash] The request environment.
      # @return [Hash]
      def call(env)
        @app.call(env)

        return env if env[:type] == :raw

        env[:response] = DataTransformer.transform(env[:response])
        env
      end
    end
  end
end
