# MikrotikClient

A modern, high-performance, and multi-tenant Ruby client for MikroTik RouterOS v6 and v7.

MikrotikClient is built with a modular architecture inspired by Faraday and an ORM inspired by ActiveResource. It features advanced connection pooling, automatic protocol detection, and a flexible middleware stack.

## Key Features

- **Dual Protocol Support:** Native Binary API (v6/v7) and REST API (v7.1+).
- **Connection Pooling:** Persistent TCP sockets with automatic reaper for idle connections.
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

### Rails Integration

Run the installer to create the initializer:

```bash
$ rails generate mikrotik_client:install
```

## Basic Usage

### Configuration

Set up global defaults in `config/initializers/mikrotik_client.rb`:

```ruby
MikrotikClient.configure do |config|
  config.pool_size = 5
  config.idle_timeout = 300 # 5 minutes
end
```

### Context Scoping (Multi-tenancy)

In a multi-tenant environment (e.g., Sidekiq job or Rails controller), you can set the context for all subsequent ORM calls:

```ruby
# Temporary scope (ideal for Jobs or Scripts)
MikrotikClient.with_config(host: '10.0.0.1', user: 'admin', pass: 'pass') do
  interfaces = Interface.all
end

# Persistent scope (ideal for Rails before_action)
MikrotikClient::Current.config = { host: '10.0.0.1', user: 'admin', pass: 'pass' }
# Now you can use models directly
IpAddress.all
```

## ORM Usage

Define your models by inheriting from `MikrotikClient::Base`:

```ruby
class IpAddress < MikrotikClient::Base
  self.mikrotik_path = "/ip/address"
end
```

### CRUD Operations

```ruby
# READ
addresses = IpAddress.all
ether1_ips = IpAddress.where(interface: 'ether1')

# CREATE
new_ip = IpAddress.create(address: '1.1.1.1/24', interface: 'ether1')

# UPDATE
new_ip.update(disabled: true)
# or
new_ip.comment = "Added via Gem"
new_ip.save

# DELETE
new_ip.destroy
```

## Advanced Client Usage

If you need low-level access, you can build a custom client:

```ruby
client = MikrotikClient.new do |conn|
  conn.host = '10.0.0.1'
  conn.user = 'admin'
  conn.pass = 'password'
  conn.adapter :binary # or :http for REST API v7
  
  conn.use MikrotikClient::Middleware::Logger
  conn.use MikrotikClient::Middleware::RaiseError
  conn.use MikrotikClient::Middleware::Transformer
end

response = client.get('/ip/address', { interface: 'ether1' })
```

## Middlewares

The client uses a pipeline of middlewares to process requests and responses:

1.  **Logger:** Uses `ActiveSupport::Notifications` and the global logger.
2.  **RaiseError:** Converts MikroTik `!trap` and HTTP errors into semantic Ruby exceptions (`NotFound`, `Conflict`, `PermissionError`).
3.  **Transformer:** Converts kebab-case keys to snake_case symbols and casts strings to Booleans/Integers.
4.  **Encoder:** Transparently handles ISO-8859-1 encoding for MikroTik v6.

## Development

Run tests against a real MikroTik device (v6 or v7):

```bash
MTIK_HOST=10.0.0.1 MIK_USER=admin MTIK_PASS=pass bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
