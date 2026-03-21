# frozen_string_literal: true

require "active_support/current_attributes"

module MikrotikClient
  # Thread-safe storage for the current MikroTik context.
  # This allows the ORM to know which device to talk to without 
  # passing a client around.
  #
  # @author Gabriel
  # @since 0.1.0
  class Current < ActiveSupport::CurrentAttributes
    # @return [Hash] The active configuration (host, user, pass, port, adapter).
    attribute :config
  end
end
