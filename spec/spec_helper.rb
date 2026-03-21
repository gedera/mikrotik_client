# frozen_string_literal: true

require "mikrotik_client"
require "pry"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configuración para MikroTik v6 (Binary)
  def v6_config
    {
      host: ENV["MTIK_HOST"] || "localhost",
      user: ENV["MTIK_USER"] || "admin",
      pass: ENV["MTIK_PASS"] || "admin",
      port: (ENV["MTIK_V6_PORT"] || 28728).to_i,
      adapter: (ENV["MTIK_V6_ADAPTER"] || "binary").to_sym,
      ssl: false # v6 API usually plain text
    }
  end

  # Configuración para MikroTik v7 (HTTP/REST)
  def v7_config
    {
      host: ENV["MTIK_HOST"] || "localhost",
      user: ENV["MTIK_USER"] || "admin",
      pass: ENV["MTIK_PASS"] || "admin",
      port: (ENV["MTIK_V7_PORT"] || 8080).to_i,
      adapter: (ENV["MTIK_V7_ADAPTER"] || "http").to_sym,
      ssl: ENV["MTIK_V7_SSL"] != "false",
      ssl_verify: false
    }
  end

  # Limpiar el Registry entre tests
  config.before(:each) do
    MikrotikClient::Registry.instance.instance_variable_set(:@pools, {})
  end
end
