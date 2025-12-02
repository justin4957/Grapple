# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Grapple is a high-performance distributed graph database built with Elixir. It uses ETS for sub-millisecond in-memory storage, supports Cypher-like queries, includes built-in analytics (PageRank, betweenness, community detection), and features optional multi-node clustering with tiered storage (ETS → Mnesia → DETS).

## Common Commands

```bash
# Install dependencies
mix deps.get

# Compile (with warnings as errors for CI)
mix compile --warnings-as-errors

# Run all tests
mix test

# Run specific test file
mix test test/grapple/query/executor_test.exs

# Run test by line number
mix test test/grapple_test.exs:28

# Run integration tests only
mix test --only integration

# Run property-based tests
mix test test/grapple/property_test.exs

# Coverage report
mix coveralls.html

# Format code (required before PRs)
mix format

# Verify formatting
mix format --check-formatted

# Static analysis
mix credo
mix dialyzer

# Security audit
mix deps.audit

# Generate documentation
MIX_ENV=dev mix docs

# Run benchmarks
mix bench

# Start interactive shell
iex -S mix
```

## Architecture

### Module Structure

```
lib/grapple/
├── grapple.ex                    # Main public API
├── application.ex                # OTP supervision tree
├── storage/
│   └── ets_graph_store.ex        # Primary storage (GenServer)
├── query/
│   ├── executor.ex               # Query execution
│   ├── language.ex               # Cypher-like parser
│   └── ets_optimizer.ex          # Query plan caching
├── analytics/
│   ├── analytics.ex              # Public analytics API
│   ├── centrality.ex             # PageRank, betweenness, closeness
│   ├── community.ex              # Connected components, clustering
│   └── metrics.ex                # Graph density, diameter, etc.
├── distributed/
│   ├── cluster_manager.ex        # Multi-node coordination
│   ├── replication_engine.ex     # Data replication strategies
│   ├── lifecycle_manager.ex      # Tiered storage management
│   └── health_monitor.ex         # Node health checks
├── auth/
│   ├── auth.ex                   # JWT authentication
│   ├── permissions.ex            # RBAC system
│   ├── guard.ex                  # Permission guards
│   └── audit_log.ex              # Security audit logging
├── cli/
│   ├── shell.ex                  # Interactive CLI
│   └── autocomplete.ex           # Tab completion
└── visualization/
    └── ascii_renderer.ex         # ASCII graph visualization
```

### Key Design Patterns

- **ETS for reads, GenServer for writes**: ETS tables are public with `read_concurrency: true` for lock-free concurrent reads. All writes go through the `EtsGraphStore` GenServer for serialization.

- **Three-tier storage**: Hot (ETS, <1ms) → Warm (Mnesia, 1-5ms, replicated) → Cold (DETS, disk-based). Managed by `LifecycleManager`.

- **Indexes**: Property indexes (`{key, value} → node_id`) and label indexes (`label → edge_id`) for O(1) lookups.

### ETS Tables

- `:grapple_nodes` - Node storage
- `:grapple_edges` - Edge storage
- `:grapple_node_edges_out` / `_in` - Adjacency lists
- `:grapple_property_index` - Property lookups
- `:grapple_label_index` - Edge label lookups

## Testing

- **Unit tests**: `test/grapple/**/*_test.exs`
- **Integration tests**: Tagged with `@moduletag :integration`, run with `--only integration`
- **Property tests**: `test/grapple/property_test.exs` using StreamData

Tests clear ETS state via setup blocks. When adding tests that interact with the graph store, ensure proper isolation.

## CI Pipeline

GitHub Actions runs on PRs to main:
1. `mix compile --warnings-as-errors`
2. `mix format --check-formatted`
3. `mix test` (unit + integration + property-based)
4. `mix coveralls.html`
5. `mix credo` (static analysis)
6. `mix dialyzer` (type checking)
7. `mix deps.audit` (security)

## Web Dashboard

Phoenix LiveView dashboard at `lib/grapple_web/`:
- `/dashboard` - Overview
- `/graph` - Graph explorer
- `/query` - Query interface
- `/analytics` - Analytics results
- `/cluster` - Cluster status

Start with `iex -S mix phx.server` (port 4000).
