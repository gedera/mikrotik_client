# MikrotikClient — Project Standards

For global observability and logging standards, see `~/.claude/CLAUDE.md`.

## Observability — Project-Specific

Log lines in this gem always use `component=mikrotik_client` as the component name.

Standard events and their required fields:

| Event | Fields |
|-------|--------|
| `request` | `method`, `path`, `host`, `adapter`, `duration_ms`, `status` |
| `request_detail` | `params`, `body` (sanitized), `response` |
| `pool_created` | `key`, `adapter`, `pool_size` |
| `pool_pruned` | `key`, `idle_for_s` |
| `reaper_error` | `error_class`, `error` |

ActiveSupport::Notifications event: `request.mikrotik_client`
Payload: `:method`, `:path`, `:host`, `:adapter`, `:duration_ms`, `:status`, `:error_class`, `:error_message`

## Architecture Contracts

- **Adapters** receive `ConnectionSettings` via constructor: `initialize(settings)`
- **Middleware** follows Rack pattern: `call(env)` wraps `@app.call(env)`, returns `env`
- **Registry** is a thread-safe singleton — double-checked lock with `INSTANCE_MUTEX`
- **Scope** is lazy — executes on first enumeration, cached in `@records`, cleared with `reload`
- **DataTransformer** is the single source of truth for response transformation — never duplicate
- `ConnectionSettings#validate!` must be called before creating a pool

## Conventions

- `frozen_string_literal: true` on every file
- Explicit `.to_s` on all key/value pairs written to the socket
- `:stream` mode is Binary-only — raise `NotImplementedError` in HTTP adapter
- `env[:type]` defaults to `:orm` — `:raw` skips Transformer, `:stream` uses `on_data` callback
