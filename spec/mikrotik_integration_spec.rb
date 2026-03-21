# frozen_string_literal: true

require "spec_helper"

RSpec.shared_examples "a Mikrotik integration" do |config_method|
  let(:config) { send(config_method) }
  
  let(:client) do
    MikrotikClient.configure do |c|
      c.log_level = Logger::DEBUG
    end

    MikrotikClient.new do |conn|
      conn.host = config[:host]
      conn.port = config[:port]
      conn.user = config[:user]
      conn.pass = config[:pass]
      conn.adapter config[:adapter], ssl: config[:ssl], ssl_verify: config[:ssl_verify]
      
      conn.use MikrotikClient::Middleware::Transformer
      conn.use MikrotikClient::Middleware::RequestTransformer
      conn.use MikrotikClient::Middleware::Logger
      conn.use MikrotikClient::Middleware::RaiseError
      conn.use MikrotikClient::Middleware::Encoder
    end
  end

  describe "Basic Connectivity" do
    it "successfully connects and authenticates" do
      expect { client.get("/system/resource") }.not_to raise_error
    end

    it "returns system resources with expected keys" do
      response = client.get("/system/resource")
      data = response.is_a?(Array) ? response.first : response
      expect(data).to have_key(:uptime)
      expect(data).to have_key(:version)
    end
  end

  describe "Critical Routes (GET)" do
    ["/ip/address", "/interface"].each do |path|
      it "fetches data from #{path}" do
        response = client.get(path)
        expect(response).to be_an(Array)
        expect(response.first.keys.first).to be_a(Symbol) if response.any?
      end
    end
  end

  describe "Full CRUD Cycle" do
    let(:list_name) { "test-gem-#{config_method}" }
    let(:test_ip) { "1.2.3.4" }
    let(:updated_ip) { "4.3.2.1" }

    it "performs a complete create, update, and delete cycle" do
      # 0. PRE-CLEANUP
      existing = client.get("/ip/firewall/address-list", { list: list_name })
      existing.each { |item| client.delete("/ip/firewall/address-list", { id: item[:id] }) }

      # 1. CREATE
      create_resp = client.post("/ip/firewall/address-list", { address: test_ip, list: list_name })
      item_id = create_resp[:id]
      expect(item_id).to start_with("*")
      sleep 0.2

      # 1b. CONFLICT
      expect {
        client.post("/ip/firewall/address-list", { address: test_ip, list: list_name })
      }.to raise_error(MikrotikClient::Conflict)

      # 2. READ
      items = client.get("/ip/firewall/address-list", { list: list_name })
      expect(items.any? { |i| i[:address] == test_ip }).to be true

      # 3. UPDATE
      client.put("/ip/firewall/address-list", { address: updated_ip }, { id: item_id })
      sleep 0.2
      updated_items = client.get("/ip/firewall/address-list", { id: item_id })
      expect(updated_items.first[:address]).to eq(updated_ip)

      # 4. DELETE
      client.delete("/ip/firewall/address-list", { id: item_id })
      final_check = client.get("/ip/firewall/address-list", { id: item_id })
      expect(final_check).to be_empty
    end
  end
end

RSpec.describe "Mikrotik Integration" do
  context "with MikroTik v6 (Binary API)" do
    it_behaves_like "a Mikrotik integration", :v6_config
  end

  context "with MikroTik v7 (REST API)" do
    it_behaves_like "a Mikrotik integration", :v7_config
  end
end
