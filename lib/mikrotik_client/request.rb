# frozen_string_literal: true

module MikrotikClient
  # Represents an outgoing request to the MikroTik API.
  # Yielded to blocks in client.get, client.post, etc.
  #
  # @attr [String] path The target path.
  # @attr [Hash] params Query parameters or filters.
  # @attr [Hash] body Data for POST/PUT operations.
  # @attr [Symbol] type The request type (:orm, :raw, :stream).
  # @attr [Proc] on_data Callback for streaming data.
  class Request
    attr_accessor :path, :params, :body, :type, :on_data

    def initialize(path = nil, params = {}, body = nil)
      @path = path
      @params = params || {}
      @body = body
      @type = :orm
    end
  end
end
