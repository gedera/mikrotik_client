# Observability Standards — MikrotikClient

This document is the single source of truth for logging and observability conventions in this gem.
All AI assistants and contributors must follow these standards when writing or reviewing code.

---

## Log Format

All log lines use **structured `key=value` pairs** on a single line.
This format is natively parseable by Datadog, ELK, Loki, CloudWatch, and Splunk without extra configuration.

```
component=mikrotik_client event=<event_name> [context fields] [optional fields]
```

Every line **must** start with:
```
component=mikrotik_client event=<event_name>
```

---

## Log Levels

| Level   | When to use |
|---------|-------------|
| `ERROR` | An exception occurred (request failure, background thread error) |
| `WARN`  | Something unexpected happened but execution continued (logger failure, notification failure) |
| `INFO`  | Normal operational events (every request, pool lifecycle) |
| `DEBUG` | Full request detail — only emitted when log level permits |

**Never use `Kernel#warn` or `$stderr.puts`.** Always use `MikrotikClient.logger`.

---

## Standard Events

### Request (emitted by `Middleware::Logger`)

**INFO — always:**
```
component=mikrotik_client event=request method=GET path=/ip/address host=10.0.0.1 adapter=binary duration_ms=4.02 status=ok
component=mikrotik_client event=request method=POST path=/ip/firewall/address-list host=10.0.0.1 adapter=binary duration_ms=8.44 status=error error_class=MikrotikClient::Conflict error=already have such entry
```

Required fields: `method`, `path`, `host`, `adapter`, `duration_ms`, `status`
Optional on error: `error_class`, `error_message`

**DEBUG — only when level permits (use block form):**
```
component=mikrotik_client event=request_detail params={"interface"=>"ether1"}
component=mikrotik_client event=request_detail body={"pass"=>"[FILTERED]"}
component=mikrotik_client event=request_detail response=[{:address=>"10.0.0.1/24"}]
```

### Pool Lifecycle (emitted by `Registry`)

```
component=mikrotik_client event=pool_created key=admin@10.0.0.1:8728 adapter=binary pool_size=5
component=mikrotik_client event=pool_pruned key=admin@10.0.0.1:8728 idle_for_s=312
```

### Background Errors (emitted by `Registry::Reaper`)

```
component=mikrotik_client event=reaper_error error_class=Errno::ECONNRESET error=Connection reset by peer
```

### Internal Failures (logger or notification failure)

```
component=mikrotik_client event=logger_failure error=<message>
component=mikrotik_client event=notification_failure error=<message>
```

---

## Timing

Always use `Process.clock_gettime(Process::CLOCK_MONOTONIC)` for duration measurement.
Never use `Time.now` for timing — it is affected by system clock changes.

```ruby
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
# ... work ...
duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
```

---

## Sensitive Data Filtering

The following key patterns must **never** appear in plaintext in log output.
Any hash logged at DEBUG level must be passed through `sanitize()` first.

Filtered keys (case-insensitive, substring match):
- `password`
- `pass`
- `passwd`
- `secret`
- `token`

Filtered values are replaced with `[FILTERED]`.

```ruby
# Current implementation in Middleware::Logger
SENSITIVE_KEYS = %w[password pass passwd secret token].freeze

def sanitize(data)
  return data unless data.is_a?(Hash)
  data.each_with_object({}) do |(k, v), h|
    h[k] = SENSITIVE_KEYS.any? { |s| k.to_s.downcase.include?(s) } ? "[FILTERED]" : v
  end
end
```

---

## DEBUG Block Form

Always use the block form for DEBUG lines so Ruby skips string interpolation when the level doesn't permit it:

```ruby
# Correct — block only evaluated if DEBUG is active
MikrotikClient.logger.debug { "component=mikrotik_client event=request_detail response=#{expensive_call.inspect}" }

# Wrong — string always interpolated regardless of log level
MikrotikClient.logger.debug "component=mikrotik_client event=request_detail response=#{expensive_call.inspect}"
```

---

## Logger Configuration

`Config#logger=` and `Config#log_level=` apply the level immediately on assignment.
The logger is always in sync — no manual `apply_log_level!` call needed.

```ruby
MikrotikClient.configure do |config|
  config.logger    = Rails.logger    # applies current log_level immediately
  config.log_level = Logger::DEBUG   # applies to current logger immediately
end
```

---

## ActiveSupport::Notifications

Every request publishes a `request.mikrotik_client` event after completion.
The payload contains all context needed for external metrics or tracing.

**Payload keys:**

| Key             | Type    | Description                        |
|-----------------|---------|------------------------------------|
| `:method`       | Symbol  | `:get`, `:post`, `:put`, `:delete` |
| `:path`         | String  | API path (e.g. `/ip/address`)      |
| `:host`         | String  | MikroTik device host               |
| `:adapter`      | Symbol  | `:binary` or `:http`               |
| `:duration_ms`  | Float   | Request duration in milliseconds   |
| `:status`       | Symbol  | `:ok` or `:error`                  |
| `:error_class`  | String  | Exception class name (errors only) |
| `:error_message`| String  | Exception message (errors only)    |

---

## Resilience Rules

1. **Logger failures must never affect request flow.** Wrap `log_request` and `publish_notification` in `rescue`.
2. **The logger rescue itself must never raise.** Use `rescue nil` as the last resort.
3. **Exceptions must be captured before `ensure`** so the status field reflects the real outcome.

```ruby
def call(env)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  exception = nil

  @app.call(env)
rescue => exception
  raise
ensure
  duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  log_request(env, duration_ms, exception)
  publish_notification(env, duration_ms, exception)
end
```
