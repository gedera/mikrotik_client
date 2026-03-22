# MikrotikClient — Project Standards

## Observability & Logging

### Format

Structured `key=value` pairs on a single line. Compatible with Datadog, ELK, Loki, CloudWatch, Splunk.

Every log line must start with: `component=mikrotik_client event=<event_name>`

### Log Levels

| Level | When |
|-------|------|
| `ERROR` | Exception occurred |
| `WARN`  | Unexpected but execution continued |
| `INFO`  | Normal operational events |
| `DEBUG` | Full detail — block form only |

Never use `Kernel#warn` or `$stderr`. Always use `MikrotikClient.logger`.

### Standard Events

| Event | Level | Required Fields |
|-------|-------|-----------------|
| `request` | INFO | `method`, `path`, `host`, `adapter`, `duration_ms`, `status` |
| `request_detail` | DEBUG | `params`, `body` (sanitized), `response` |
| `pool_created` | INFO | `key`, `adapter`, `pool_size` |
| `pool_pruned` | INFO | `key`, `idle_for_seconds` |
| `reaper_error` | ERROR | `error_class`, `error` |

### Rules

- DEBUG always uses block form: `logger.debug { "..." }`
- Timing via `Process.clock_gettime(Process::CLOCK_MONOTONIC)`, never `Time.now`
- Filter sensitive keys (`pass`, `password`, `secret`, `token`, `api_key`) → `[FILTERED]`
- Logger failures must never affect request flow — wrap in `rescue`
- `Config#logger=` and `Config#log_level=` apply level immediately on assignment

## Architecture Contracts

- **Adapters** receive `ConnectionSettings` via constructor: `initialize(settings)`
- **Middleware** Rack pattern: `call(env)` wraps `@app.call(env)`, returns `env`
- **Registry** thread-safe singleton — double-checked lock with `INSTANCE_MUTEX`
- **Scope** lazy — executes on first enumeration, cached in `@records`, cleared with `reload`
- **DataTransformer** single source of truth for response transformation — never duplicate
- `ConnectionSettings#validate!` must be called before creating a pool

## Conventions

- `frozen_string_literal: true` on every file
- Explicit `.to_s` on all key/value pairs written to the socket
- `:stream` mode Binary-only — raise `NotImplementedError` in HTTP adapter
- `env[:type]` defaults to `:orm` — `:raw` skips Transformer, `:stream` uses `on_data` callback
