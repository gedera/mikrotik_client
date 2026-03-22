# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Advanced Request Modes (Integration)" do
  let(:v6_client) do
    MikrotikClient.new do |conn|
      config = v6_config
      conn.host = config[:host]
      conn.user = config[:user]
      conn.pass = config[:pass]
      conn.port = config[:port]
      conn.adapter config[:adapter]
      
      conn.use MikrotikClient::Middleware::Transformer
      conn.use MikrotikClient::Middleware::RaiseError
    end
  end

  describe "Raw Mode (:raw)" do
    it "returns data with original MikroTik keys without transformation" do
      # En modo :raw, usamos el path completo del comando
      response = v6_client.get("/system/resource/print") do |req|
        req.type = :raw
      end

      resource = response.first
      expect(resource.keys).to include("cpu-load")
    end
  end

  describe "Streaming Mode (:stream)" do
    it "processes multiple data packets and stops when requested" do
      packets = []
      
      # Obtenemos la primera interfaz disponible para asegurar que el test no falle
      interface = v6_client.get("/interface").first[:name]
      
      begin
        Timeout.timeout(5) do
          v6_client.get("/interface/monitor-traffic") do |req|
            req.params = { interface: interface, once: true }
            req.type = :stream
            req.on_data = ->(data) do
              packets << data
              :stop if packets.size >= 1
            end
          end
        end
      rescue Timeout::Error
        fail "Streaming test timed out - no data received from router on interface #{interface}"
      end

      expect(packets.size).to be >= 1
      expect(packets.first).to have_key(:rx_bits_per_second)
    end

    it "properly handles errors during a stream" do
      expect {
        v6_client.get("/non-existent-path") do |req|
          req.type = :stream
          req.on_data = ->(_) { :stop }
        end
      }.to raise_error(MikrotikClient::NotFound)
    end
  end
end
