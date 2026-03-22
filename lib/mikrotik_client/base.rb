# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/hash/indifferent_access"

module MikrotikClient
  # Base class for MikroTik models, inspired by ActiveResource.
  # Handles connectivity via the pooling system and the current context.
  #
  # @example
  #   class IpAddress < MikrotikClient::Base
  #     self.mikrotik_path = "/ip/address"
  #   end
  #
  #   # Usage:
  #   IpAddress.all
  #   IpAddress.where(interface: "ether1").all
  #
  # @author Gabriel
  # @since 0.1.0
  class Base
    class_attribute :mikrotik_path
    
    # @return [Hash] Attributes of the record.
    attr_accessor :attributes

    # @return [Boolean] Is this record already on the MikroTik?
    attr_reader :persisted

    # @return [Client, nil] The explicit client used for this instance.
    attr_accessor :client

    # Initialize a new resource.
    #
    # @param attributes [Hash]
    # @param persisted [Boolean] Is this record already on the MikroTik?
    # @param client [Client, nil] Explicit client to use for this instance.
    def initialize(attributes = {}, persisted = false, client: nil)
      @attributes = attributes.with_indifferent_access
      @persisted = persisted
      @client = client
    end

    class << self
      # Delegate query methods to a new Scope.
      # @return [Scope]
      def all
        Scope.new(self)
      end

      # Find a resource by ID.
      # @param id [String] MikroTik ID (e.g., "*1")
      # @return [Base, nil]
      def find(id)
        where(id: id).first
      end

      # Find resources matching the criteria.
      # @param clauses [Hash] Filters.
      # @return [Scope]
      def where(clauses = {})
        all.where(clauses)
      end

      # Injects an explicit client for the query.
      # @param client [Client]
      # @return [Scope]
      def with_client(client)
        all.with_client(client)
      end

      # Create and save a new resource.
      # @param attributes [Hash]
      # @return [Base]
      def create(attributes = {})
        resource = new(attributes)
        resource.save
        resource
      end

      # Builds a connection using the current thread context.
      # This is the fallback connection if no explicit client is provided.
      #
      # @return [Client]
      def default_connection
        config = MikrotikClient::Current.config
        raise Error, "MikrotikClient::Current.config not set for this thread" unless config

        # Extract adapter name and additional options (like ssl, ssl_verify, pool_size)
        adapter_name = config[:adapter] || :binary
        options = config.except(:host, :port, :user, :pass, :adapter)

        MikrotikClient.new do |c|
          c.host = config[:host]
          c.port = config[:port]
          c.user = config[:user]
          c.pass = config[:pass]
          c.adapter adapter_name, **options
        end
      end
    end


    # Primary ID of the record.
    # @return [String]
    def id
      attributes[:id]
    end

    # Is this a new record?
    def new_record?
      !@persisted
    end

    # Has this record been persisted?
    def persisted?
      @persisted
    end

    # Returns the connection to use for this instance.
    # @return [Client]
    def connection
      @client || self.class.default_connection
    end

    # Saves the resource (POST for new, PUT for existing).
    # @return [Boolean]
    def save
      new_record? ? create_resource : update_resource
    end

    # Deletes the resource from the MikroTik.
    # @return [Boolean]
    def destroy
      connection.delete(mikrotik_path, { id: id })
      @persisted = false
      true
    end

    # Update attributes and save.
    # @param attrs [Hash]
    # @return [Boolean]
    def update(attrs = {})
      @attributes.merge!(attrs.with_indifferent_access)
      save
    end

    # Metaprogramming for attribute accessors.
    def method_missing(method_name, *args, &block)
      key = method_name.to_s
      if key.end_with?("=")
        attributes[key.chomp("=")] = args.first
      elsif attributes.key?(key)
        attributes[key]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      attributes.key?(method_name.to_s.chomp("=")) || super
    end

    private

    def create_resource
      resp = connection.post(mikrotik_path, attributes)
      new_id = resp[:id] || resp["id"]
      raise Error, "MikroTik did not return an ID after create on #{mikrotik_path}" unless new_id

      attributes[:id] = new_id
      @persisted = true
      true
    end

    def update_resource
      connection.put(mikrotik_path, attributes.except(:id), { id: id })
      true
    end
  end
end
