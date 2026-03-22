# frozen_string_literal: true

require "spec_helper"

class FirewallAddress < MikrotikClient::Base
  self.mikrotik_path = "/ip/firewall/address-list"
end

RSpec.shared_examples "a Mikrotik ORM" do |config_method|
  let(:config) { send(config_method) }
  let(:list_name) { "orm-test-#{config_method}" }

  around(:each) do |example|
    MikrotikClient.with_config(config) do
      begin
        FirewallAddress.where(list: list_name).each(&:destroy)
      rescue MikrotikClient::Error
      end
      example.run
      begin
        FirewallAddress.where(list: list_name).each(&:destroy)
      rescue MikrotikClient::Error
      end
    end
  end

  describe "Persistence (CRUD)" do
    it "creates, updates and destroys a record" do
      # CREATE
      address = FirewallAddress.create(address: "10.10.10.10", list: list_name)
      expect(address).to be_persisted
      expect(address.id).to start_with("*")

      # UPDATE
      address.address = "10.10.10.11"
      expect(address.save).to be true
      
      reloaded = FirewallAddress.find(address.id)
      expect(reloaded.address).to eq("10.10.10.11")

      # DELETE
      expect(address.destroy).to be true
      expect(FirewallAddress.find(address.id)).to be_nil
    end
  end

  describe "Querying" do
    it "filters records using .where" do
      FirewallAddress.create(address: "1.1.1.1", list: list_name)
      FirewallAddress.create(address: "1.1.1.2", list: list_name)
      
      results = FirewallAddress.where(list: list_name)
      expect(results.count).to eq(2)
      expect(results.first).to be_a(FirewallAddress)
    end
  end
end

RSpec.describe MikrotikClient::Base do
  context "using MikroTik v6 (Binary)" do
    it_behaves_like "a Mikrotik ORM", :v6_config
  end

  context "using MikroTik v7 (REST)" do
    it_behaves_like "a Mikrotik ORM", :v7_config
  end

  describe "Thread Safety & Scoping" do
    it "raises error if config is missing" do
      MikrotikClient::Current.config = nil
      expect { FirewallAddress.all.to_a }.to raise_error(MikrotikClient::Error, /not set/)
    end

    it "switches context using with_config" do
      MikrotikClient::Current.config = nil
      test_config = { host: "1.1.1.1", user: "test" }
      MikrotikClient.with_config(test_config) do
        expect(MikrotikClient::Current.config[:host]).to eq("1.1.1.1")
      end
      expect(MikrotikClient::Current.config).to be_nil
    end
  end
end
