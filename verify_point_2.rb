# frozen_string_literal: true

require_relative "lib/mikrotik_client"
require "rspec"

# Mock Adapter
module MikrotikClient
  module Adapter
    class MockPoint2 < Base
      def initialize(options = {}) ; super ; end
      def connect! ; self ; end
      def call(env)
        env[:response] = if env[:method] == :get
          [{ id: "*1", address: "1.1.1.1" }]
        else
          { id: "*1" }
        end
      end
    end
  end
end

MikrotikClient::AdapterRegistry.register :mock2, MikrotikClient::Adapter::MockPoint2

class IpAddress < MikrotikClient::Base
  self.mikrotik_path = "/ip/address"
end

RSpec.describe "ORM Client Injection (Point 2)" do
  let(:custom_client) do
    MikrotikClient.new do |c|
      c.adapter :mock2
      c.host = "custom"
      c.user = "admin"
    end
  end

  it "allows explicit client injection via .with_client" do
    scope = IpAddress.with_client(custom_client)
    expect(scope).to be_a(MikrotikClient::Scope)
    expect(scope.client).to eq(custom_client)
    
    addresses = scope.all
    expect(addresses.first).to be_a(IpAddress)
    expect(addresses.first.client).to eq(custom_client)
  end

  it "persists the client in the instance for future operations" do
    address = IpAddress.with_client(custom_client).first
    
    # This should use custom_client, not default_connection
    expect(address.connection).to eq(custom_client)
    
    # Test destroy
    expect(custom_client).to receive(:delete).with("/ip/address", { id: "*1" }).and_call_original
    address.destroy
  end

  it "still uses default_connection if no client is provided" do
    MikrotikClient::Current.config = { host: "default", user: "a", pass: "p", adapter: :mock2 }
    
    address = IpAddress.first
    expect(address.client).to be_nil
    expect(address.connection.configuration.host).to eq("default")
  end
end

RSpec::Core::Runner.run(['--format', 'documentation'])
