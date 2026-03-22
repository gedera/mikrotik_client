# frozen_string_literal: true

module MikrotikClient
  # Manages the middleware pipeline for a client.
  # Allows pre-compiling the chain for better performance.
  class MiddlewareStack
    def initialize
      @middlewares = []
    end

    # Adds a middleware to the stack.
    # @param klass [Class]
    # @param args [Array]
    def use(klass, *args)
      @middlewares << [klass, args]
    end

    # Returns the number of middlewares in the stack.
    def size
      @middlewares.size
    end

    # Compiles the stack into a callable app chain.
    #
    # @param adapter [Adapter::Base] The final transport adapter.
    # @return [Object] The head of the middleware chain.
    def build(adapter)
      @middlewares.reverse.reduce(adapter) do |next_app, (klass, args)|
        klass.new(next_app, *args)
      end
    end

    # Deep copy support.
    def initialize_copy(other)
      super
      @middlewares = other.instance_variable_get(:@middlewares).dup
    end
  end
end
