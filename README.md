# MikrotikClient

A modern, high-performance, and multi-tenant Ruby client for MikroTik RouterOS v6 and v7, designed with a familiar **Faraday-like interface**.

MikrotikClient is built with a modular architecture that features advanced connection pooling, automatic protocol detection, and a flexible middleware stack. It also includes an ORM inspired by ActiveResource for effortless resource management.

## Key Features

- **Faraday-inspired API:** Familiar block-based configuration and request cycle.
- **Dual Protocol Support:** Native Binary API (v6/v7) and REST API (v7.1+).
- **Connection Pooling:** Persistent TCP sockets with an automatic reaper for idle connections.
- **Multi-tenancy Ready:** Seamlessly switch between thousands of routers using thread-safe context scoping.
- **Middleware Stack:** Instrumented logs, semantic error handling, and automatic data transformation.
- **ActiveRecord-like ORM:** Simple and expressive syntax for managing MikroTik resources.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mikrotik_client'
```

And then execute:

```bash
$ bundle install
```

## Advanced Client Usage (Faraday Style)

The core of MikrotikClient is its flexible client, which works exactly like Faraday. You can initialize it with a base URL/path and configure it via a block.

### Initialization & Configuration

```ruby
client = MikrotikClient.new("/ip/address") do |conn|
  # Connection settings
  conn.host = '192.168.88.1'
  conn.user = 'admin'
  conn.pass = 'password'
  
  # Adapter selection (:binary for API, :http for REST)
  conn.adapter :binary
  
  # Default parameters for all requests from this client
  conn.params = { interface: 'ether1' }
  
  # Middleware stack configuration
  conn.use MikrotikClient::Middleware::Logger
  conn.use MikrotikClient::Middleware::RaiseError
  conn.use MikrotikClient::Middleware::Transformer
end
```

### Making Requests

You can use `send(method)` or direct methods like `get`, `post`, `put`, and `delete`. Each method accepts an optional block to configure the specific request.

```ruby
# GET request with additional filters
response = client.send('get') do |req|
  req.params[:disabled] = 'no'
end

# POST request with a body
client.post("/ip/firewall/filter") do |req|
  req.body = {
    chain: 'input',
    action: 'drop',
    protocol: 'icmp'
  }
end

# The request object 'req' allows full control:
# req.path   => Override or extend the base path
# req.params => Specific query parameters/filters
# req.body   => Data for write operations
```

## ORM Usage

For a higher-level abstraction, use the built-in ORM. Define your models by inheriting from `MikrotikClient::Base`:

```ruby
class IpAddress < MikrotikClient::Base
  self.mikrotik_path = "/ip/address"
end
```

### CRUD Operations

The ORM automatically uses the current connection context:

```ruby
# READ
addresses = IpAddress.all
ether1_ips = IpAddress.where(interface: 'ether1')

# CREATE
new_ip = IpAddress.create(address: '1.1.1.1/24', interface: 'ether1')

# UPDATE
new_ip.update(disabled: true)
# or
new_ip.comment = "Updated via ORM"
new_ip.save

# DELETE
new_ip.destroy
```

## Multi-tenancy & Context Scoping

Easily manage multiple routers by wrapping your code in a `with_config` block:

```ruby
# Temporary scope (ideal for Background Jobs or Scripts)
MikrotikClient.with_config(host: '10.0.0.1', user: 'admin', pass: 'secret') do
  # All ORM calls here will target 10.0.0.1
  interfaces = Interface.all
end
```

## Middlewares

The client uses a pipeline of middlewares to process requests and responses:

1.  **Logger:** Uses `ActiveSupport::Notifications` and the global logger.
2.  **RaiseError:** Converts MikroTik `!trap` and HTTP errors into semantic Ruby exceptions (`NotFound`, `Conflict`, etc.).
3.  **Transformer:** Converts MikroTik kebab-case keys to snake_case symbols and handles data type casting.
4.  **Encoder:** Transparently handles encoding for different RouterOS versions.

## Development

Run tests against a real MikroTik device (v6 or v7):

```bash
MTIK_HOST=10.0.0.1 MIK_USER=admin MTIK_PASS=pass bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
