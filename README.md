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

## Global Configuration

Configure the gem once at boot time (e.g. `config/initializers/mikrotik_client.rb` in Rails):

```ruby
MikrotikClient.configure do |config|
  # Logger instance — defaults to Logger.new($stdout)
  config.logger = Rails.logger

  # Log level — defaults to Logger::INFO
  # Changing it automatically applies to the current logger instance.
  config.log_level = Logger::INFO

  # Connection timeouts (seconds)
  config.connect_timeout = 5   # default
  config.read_timeout    = 10  # default

  # Connection pool per router
  config.pool_size    = 5    # default — connections per router
  config.pool_timeout = 5    # default — seconds to wait for a free connection
  config.idle_timeout = 300  # default — seconds before an idle pool is removed
end
```

### Logger & Observability

MikrotikClient emits structured `key=value` log lines compatible with Datadog, ELK, Loki, and CloudWatch without any extra configuration.

**INFO** (every request):
```
component=mikrotik_client event=request method=GET path=/ip/address host=10.0.0.1 adapter=binary duration_ms=4.02 status=ok
component=mikrotik_client event=request method=POST path=/ip/firewall/address-list host=10.0.0.1 adapter=binary duration_ms=8.44 status=error error_class=MikrotikClient::Conflict error=already have such entry
```

**INFO** (connection pool lifecycle):
```
component=mikrotik_client event=pool_created key=admin@10.0.0.1:8728 adapter=binary pool_size=5
component=mikrotik_client event=pool_pruned key=admin@10.0.0.1:8728 idle_for_seconds=312
```

**DEBUG** (full request detail — only evaluated when log level permits):
```
component=mikrotik_client event=request_detail params={"interface"=>"ether1"}
component=mikrotik_client event=request_detail body={"pass"=>"[FILTERED]"}
component=mikrotik_client event=request_detail response=[{:address=>"10.0.0.1/24", ...}]
```

> Sensitive keys (`password`, `pass`, `passwd`, `secret`, `token`) are automatically redacted in debug body output.

#### ActiveSupport::Notifications

Every request also publishes a `request.mikrotik_client` event you can subscribe to for custom metrics or tracing:

```ruby
ActiveSupport::Notifications.subscribe("request.mikrotik_client") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  StatsD.histogram("mikrotik.request.duration", event.payload[:duration_ms],
    tags: [
      "host:#{event.payload[:host]}",
      "adapter:#{event.payload[:adapter]}",
      "status:#{event.payload[:status]}"
    ]
  )
end
```

Available payload keys: `:method`, `:path`, `:host`, `:adapter`, `:duration_ms`, `:status` (`:ok` or `:error`), `:error_class`, `:error_message`.

## Advanced Client Usage (Faraday Style)

The core of MikrotikClient is its flexible client, which works exactly like Faraday. You can initialize it with a base URL/path and configure it via a block.

### Initialization & Configuration

```ruby
client = MikrotikClient.new do |conn|
  # Connection settings
  conn.host = '192.168.88.1'
  conn.user = 'admin'
  conn.pass = 'password'
  conn.port = 8728  # default for Binary API

  # Adapter selection (:binary for v6/v7, :http for REST v7.1+)
  conn.adapter :binary

  # Middleware stack — order matters, declared top-to-bottom is execution order
  conn.use MikrotikClient::Middleware::Transformer        # response: kebab→snake_case, type casting
  conn.use MikrotikClient::Middleware::RequestTransformer # request:  snake_case→kebab, :id→.id
  conn.use MikrotikClient::Middleware::Logger             # structured logging + notifications
  conn.use MikrotikClient::Middleware::RaiseError         # maps errors to Ruby exceptions
  conn.use MikrotikClient::Middleware::Encoder            # encoding for Binary API (UTF-8↔ISO-8859-1)
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
# req.path    => Override or extend the base path
# req.params  => Specific query parameters/filters
# req.body    => Data for write operations
# req.type    => Mode: :orm (default), :raw, or :stream
# req.on_data => Callback for :stream mode
```

### Advanced Modes (Raw & Streaming)

For special operations like config exports or real-time monitoring, you can change the request type.

#### Raw Mode
Disables automatic transformations (kebab to snake_case) and returns the data exactly as it comes from the router.

```ruby
# Fetch config export without symbol/case transformations
raw_config = client.get("/export") do |req|
  req.type = :raw
end
```

#### Streaming Mode
Ideal for long-running commands that push data continuously (e.g., `monitor-traffic` or log tailing). Unlike regular requests, Streaming Mode **does not accumulate data in memory**, making it safe for hours of monitoring.

- **`req.type = :stream`**: Tells the client to enter an infinite read loop.
- **`req.on_data = ->(data) { ... }`**: A callback executed for each packet (`!re`) received.
- **Flow Control**: To stop the stream programmatically, return the symbol **`:stop`** from your callback.

```ruby
# Monitor real-time traffic on ether1
client.get("/interface/monitor-traffic") do |req|
  req.params = { interface: 'ether1' }
  req.type = :stream
  
  req.on_data = ->(data) do
    # 'data' is already transformed (e.g., :rx_bits_per_second as Integer)
    puts "Traffic In: #{data[:rx_bits_per_second]} bps"
    
    # Gracefully stop after receiving a specific threshold
    :stop if data[:rx_bits_per_second] > 1_000_000
  end
end
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

The client uses a declarative middleware pipeline. Each middleware is added explicitly with `conn.use`, and the order you declare them is the order they execute on the request (and reverse on the response).

| Middleware | Direction | Responsibility |
|---|---|---|
| `Transformer` | Response | Converts kebab-case keys to `snake_case` symbols, casts `"true"`/`"false"` to booleans, numeric strings to integers/floats. Skipped for `:raw` requests. |
| `RequestTransformer` | Request | Converts `snake_case` symbols to kebab-case strings, maps `:id` → `".id"` (MikroTik convention). |
| `Logger` | Both | Emits structured `key=value` log lines. Publishes `request.mikrotik_client` notification. Sensitive body keys are filtered. |
| `RaiseError` | Response | Maps MikroTik `!trap`/`!fatal` and HTTP error codes to typed Ruby exceptions (`NotFound`, `Conflict`, `AuthenticationError`, etc.). |
| `Encoder` | Both | Handles UTF-8 ↔ ISO-8859-1 encoding for the Binary API. No-op for the HTTP adapter. |

To add a custom middleware, implement `#call(env)` and insert it at the right position:

```ruby
class MyAuditMiddleware < MikrotikClient::Middleware::Base
  def call(env)
    @app.call(env)
    AuditLog.record(path: env[:path], method: env[:method])
    env
  end
end

conn.use MikrotikClient::Middleware::Transformer
conn.use MikrotikClient::Middleware::RequestTransformer
conn.use MikrotikClient::Middleware::Logger
conn.use MyAuditMiddleware   # runs after Logger, before RaiseError
conn.use MikrotikClient::Middleware::RaiseError
conn.use MikrotikClient::Middleware::Encoder
```

## Development

Run tests against a real MikroTik device (v6 or v7):

```bash
MTIK_HOST=10.0.0.1 MIK_USER=admin MTIK_PASS=pass bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
