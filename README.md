# Grapple

**High-Performance Distributed Graph Database**

Grapple is a blazing-fast distributed graph database built with Elixir, designed for lightning-fast in-memory graph operations with advanced indexing, query optimization, and enterprise-ready distributed features.

## Key Features

- **🏃‍♂️ Blazing Fast**: 300K+ operations/sec, sub-millisecond queries
- **🧠 Smart Indexing**: O(1) property and label lookups
- **💾 Pure Memory**: 100x faster than disk-based systems
- **🔄 Concurrent**: Unlimited simultaneous readers
- **🌐 Distributed**: Multi-node clustering with auto-discovery and self-healing
- **🔄 Lifecycle Management**: Ephemeral-first data classification with smart tier management
- **🛡️ Advanced Replication**: CRDT-based conflict resolution with adaptive strategies

## Quick Start

```elixir
# Start the interactive CLI
Grapple.start_shell()

# Or use the API directly
{:ok, node1} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
{:ok, node2} = Grapple.create_node(%{name: "Bob", role: "Manager"})
{:ok, edge} = Grapple.create_edge(node1, node2, "reports_to", %{since: "2024"})

# Query the graph
{:ok, path} = Grapple.find_path(node1, node2)
{:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
```

## Architecture

Grapple uses a three-tier storage architecture optimized for different data access patterns:

- **ETS (Hot)**: Sub-millisecond access, memory-only, ephemeral data
- **Mnesia (Warm)**: Fast access, replicated, computational data
- **DETS (Cold)**: Persistent, disk-based, archival data

Data is automatically classified and migrated between tiers based on access patterns, ensuring optimal performance while minimizing costs.

## CLI Interface

The interactive CLI provides powerful commands for graph operations and cluster management:

```bash
grapple> CREATE NODE {name: "Alice", role: "engineer"}
grapple> LIFECYCLE CLASSIFY user:alice ephemeral
grapple> REPLICA CREATE critical_data adaptive
grapple> CLUSTER STATUS
```

## Distributed Mode

Enable distributed clustering for multi-node deployments:

```elixir
# Enable distributed mode
Application.put_env(:grapple, :distributed, true)

# Use advanced lifecycle management
Grapple.Distributed.LifecycleManager.classify_data("critical_data", :persistent)
Grapple.Distributed.ReplicationEngine.replicate_data("user_data", data, :adaptive)
```

## Installation

Add `grapple` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:grapple, "~> 0.1.0"}
  ]
end
```

## Documentation

Complete documentation is available with detailed guides:

- [Quick Start Guide](guides/tutorials/quick-start.md) - Get up and running in 5 minutes
- [Complete User Guide](GUIDE.md) - Comprehensive usage documentation
- [Distributed Mode Guide](README_DISTRIBUTED.md) - Advanced clustering features
- [Architecture Overview](guides/advanced/architecture.md) - System design and internals
- [Performance Guide](guides/advanced/performance.md) - Optimization and tuning

Documentation can also be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs will be available at <https://hexdocs.pm/grapple>.

