# frozen_string_literal: true

require "forwardable"

module MikrotikClient
  # Handles query building and execution for ORM models.
  # Supports chaining (where) and explicit client injection.
  class Scope
    extend Forwardable
    include Enumerable

    attr_reader :model, :clauses, :client

    def_delegators :to_a, :each, :first, :last, :empty?, :count, :size, :[]

    # @param model [Class] The MikrotikClient::Base subclass.
    # @param clauses [Hash] Query filters.
    # @param client [Client, nil] Explicit client to use.
    def initialize(model, clauses: {}, client: nil)
      @model = model
      @clauses = clauses.with_indifferent_access
      @client = client
    end

    # Merges new filters into the scope.
    #
    # @param new_clauses [Hash]
    # @return [Scope] A new scope with merged filters.
    def where(new_clauses)
      spawn(clauses: @clauses.merge(new_clauses.with_indifferent_access))
    end

    # Explicitly sets the client for this scope.
    #
    # @param explicit_client [Client]
    # @return [Scope] A new scope using the provided client.
    def with_client(explicit_client)
      spawn(client: explicit_client)
    end

    # Executes the query and returns model instances.
    # @return [Array<Base>]
    def to_a
      @records ||= begin
        response = connection.get(model.mikrotik_path, @clauses)
        records = response.is_a?(Array) ? response : [response]
        records.reject(&:empty?).map { |attrs| model.new(attrs, true, client: @client) }
      end
    end

    # Returns the connection to use (explicit client or default).
    # @return [Client]
    def connection
      @client || model.default_connection
    end

    private

    # Creates a copy of the current scope with updated attributes.
    def spawn(clauses: nil, client: nil)
      self.class.new(
        model,
        clauses: clauses || @clauses,
        client: client || @client
      )
    end
  end
end
