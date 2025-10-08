# Grapple 🚀

**A High-Performance Distributed Graph Database Built with Elixir**

Grapple is a modern, distributed graph database designed for speed, scalability, and developer experience. Built on the BEAM VM, it leverages Elixir's strengths in concurrency, fault tolerance, and distributed computing to deliver a powerful graph database solution.

[![CI Status](https://github.com/justin4957/Grapple/workflows/CI/badge.svg)](https://github.com/justin4957/Grapple/actions)
[![Coverage](https://img.shields.io/badge/coverage-90%25-brightgreen.svg)](https://github.com/justin4957/Grapple)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## ✨ Features

### Core Capabilities
- 🚀 **High Performance**: 300K+ operations/sec with sub-millisecond latency
- 🧠 **Smart Indexing**: O(1) property and label lookups via ETS
- 💾 **In-Memory First**: 100x faster than disk-based alternatives
- 🔄 **Concurrent**: Thousands of simultaneous readers with lock-free data structures
- 🌐 **Distributed**: Multi-node clustering with automatic discovery and self-healing

### Advanced Analytics
- 📊 **Centrality Algorithms**: PageRank, Betweenness, Closeness
- 🔍 **Community Detection**: Connected components, clustering coefficient
- 📈 **Graph Metrics**: Density, diameter, degree distribution
- 🎯 **Path Analysis**: Shortest paths, traversal algorithms

### Developer Experience
- 🎨 **Interactive CLI**: Rich shell with autocomplete and ASCII visualization
- 📝 **Query Language**: Cypher-like pattern matching
- 🔧 **Easy Integration**: Simple API with comprehensive error handling
- 📚 **Excellent Documentation**: Guides, examples, and API docs
- 🧪 **Testing Tools**: Built-in test helpers and fixtures

### Enterprise Ready
- 🛡️ **Fault Tolerant**: Built on battle-tested BEAM VM
- 📊 **Monitoring**: Performance metrics and profiling tools
- 🔄 **Replication**: Multi-strategy replication (minimal, balanced, maximum, adaptive)
- 💾 **Tiered Storage**: ETS (hot) → Mnesia (warm) → DETS (cold)
- 🔐 **Validation**: Comprehensive input validation and error handling

## 🚀 Quick Start

### Installation

Add Grapple to your `mix.exs`:

```elixir
def deps do
  [
    {:grapple, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
# Start Grapple
{:ok, _} = Grapple.start()

# Create nodes
{:ok, alice} = Grapple.create_node(%{name: "Alice", role: "Engineer", age: 28})
{:ok, bob} = Grapple.create_node(%{name: "Bob", role: "Manager", age: 35})
{:ok, charlie} = Grapple.create_node(%{name: "Charlie", role: "Designer", age: 30})

# Create relationships
{:ok, _} = Grapple.create_edge(alice, bob, "reports_to", %{since: "2024"})
{:ok, _} = Grapple.create_edge(charlie, bob, "reports_to", %{since: "2023"})
{:ok, _} = Grapple.create_edge(alice, charlie, "collaborates_with")

# Query the graph
{:ok, path} = Grapple.find_path(alice, bob)
{:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")

# Analytics
{:ok, pageranks} = Grapple.Analytics.pagerank()
{:ok, components} = Grapple.Analytics.connected_components()
{:ok, summary} = Grapple.Analytics.summary()
```

### Interactive CLI

```bash
$ iex -S mix
iex> Grapple.start_shell()

Grapple Graph Database Shell
Type 'help' for available commands, 'quit' to exit

grapple> CREATE NODE {name: "Alice", role: "engineer"}
✅ Created node with ID: 1

grapple> CREATE EDGE (1)-[knows]->(2)
✅ Created edge with ID: 1

grapple> ANALYTICS PAGERANK
PageRank Scores (Top 10):
  1. Node 2: 0.342857
  2. Node 1: 0.285714
  ...

grapple> VISUALIZE 1 2
┌─────────┐
│ Alice   │
└────┬────┘
     │ knows
     ▼
┌─────────┐
│ Bob     │
└─────────┘
```

## 📖 Documentation

### Getting Started
- **[Quick Start Guide](guides/tutorials/quick-start.md)** - Get up and running in 5 minutes
- **[Complete User Guide](GUIDE.md)** - Comprehensive usage documentation
- **[FAQ](FAQ.md)** - Frequently asked questions

### Examples
- **[Social Network Analysis](guides/examples/social-network.md)** - Build and analyze social graphs
- **[Recommendation Engine](guides/examples/recommendation-engine.md)** - Collaborative filtering
- **[Graph Analytics](guides/examples/graph-analytics.md)** - Advanced analytics and algorithms

### Advanced Topics
- **[Architecture Overview](guides/advanced/architecture.md)** - System design and internals
- **[Performance Guide](guides/advanced/performance.md)** - Optimization and tuning
- **[Performance Monitoring](PERFORMANCE.md)** - Benchmarking and profiling tools
- **[Distributed Mode](README_DISTRIBUTED.md)** - Multi-node clustering

### Developer Resources
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute
- **[Testing Guide](TESTING.md)** - Testing infrastructure
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

## 🏗️ Architecture

Grapple uses a sophisticated three-tier storage architecture:

```
┌─────────────────────────────────────────────┐
│           Application Layer                  │
│  (API, CLI, Query Language, Analytics)       │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│          Storage Tiers                       │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  ETS (Hot Tier)                      │   │
│  │  • Sub-ms latency                    │   │
│  │  • Ephemeral data                    │   │
│  │  • Lock-free concurrent reads        │   │
│  └──────────────────────────────────────┘   │
│                  │                           │
│  ┌──────────────▼───────────────────────┐   │
│  │  Mnesia (Warm Tier)                  │   │
│  │  • 1-5ms latency                     │   │
│  │  • Replicated across nodes           │   │
│  │  • Computational data                │   │
│  └──────────────────────────────────────┘   │
│                  │                           │
│  ┌──────────────▼───────────────────────┐   │
│  │  DETS (Cold Tier)                    │   │
│  │  • Disk-persisted                    │   │
│  │  • Archival storage                  │   │
│  │  • Low access frequency              │   │
│  └──────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

### Key Components

- **Storage Layer**: ETS-based in-memory storage with advanced indexing
- **Query Engine**: Cypher-like pattern matching with optimization
- **Analytics Engine**: Built-in graph algorithms (PageRank, betweenness, etc.)
- **Distributed Layer**: Clustering, replication, and lifecycle management
- **CLI/API**: Interactive shell and programmatic interfaces

## 🎯 Use Cases

### Social Network Analysis
```elixir
# Find influencers
{:ok, pageranks} = Grapple.Analytics.pagerank()
top_influencers =
  pageranks
  |> Enum.sort_by(fn {_id, rank} -> -rank end)
  |> Enum.take(10)

# Detect communities
{:ok, communities} = Grapple.Analytics.connected_components()

# Analyze clustering
{:ok, clustering} = Grapple.Analytics.clustering_coefficient()
```

### Recommendation Systems
```elixir
# Find similar users (collaborative filtering)
{:ok, alice_neighbors} = Grapple.get_neighbors(alice_id)
recommendations =
  alice_neighbors
  |> Enum.flat_map(fn neighbor ->
    {:ok, items} = Grapple.traverse(neighbor, :likes)
    items
  end)
  |> Enum.frequencies()
  |> Enum.sort_by(fn {_item, freq} -> -freq end)
```

### Infrastructure Monitoring
```elixir
# Find critical nodes (single points of failure)
{:ok, betweenness} = Grapple.Analytics.betweenness_centrality()
critical_nodes =
  betweenness
  |> Enum.filter(fn {_id, score} -> score > 0.5 end)
  |> Enum.map(fn {id, _score} -> id end)

# Verify connectivity
{:ok, %{is_connected: connected}} = Grapple.Analytics.connectivity_metrics()
```

## 🔧 Configuration

### Basic Configuration

```elixir
# config/config.exs
config :grapple,
  # Enable distributed mode
  distributed: true,

  # Performance settings
  max_connections: 1000,
  query_timeout: 5000,

  # Storage tiers
  hot_tier_ttl: :timer.hours(1),
  warm_tier_ttl: :timer.hours(24),

  # Replication
  default_replication: :balanced,

  # Monitoring
  enable_metrics: true,
  enable_profiling: true
```

### Distributed Configuration

```elixir
# Enable clustering
Application.put_env(:grapple, :distributed, true)

# Join cluster
Grapple.Distributed.ClusterManager.join_cluster(:"node2@host")

# Configure replication
Grapple.Distributed.ReplicationEngine.replicate_data(
  "critical_data",
  data,
  :maximum  # minimal | balanced | maximum | adaptive
)
```

## 🚦 Performance

Grapple is designed for high performance:

| Operation | Throughput | Latency |
|-----------|-----------|---------|
| Node Creation | 300K+ ops/sec | <1ms |
| Edge Creation | 250K+ ops/sec | <1ms |
| Property Lookup | 500K+ ops/sec | <0.5ms |
| Traversal (depth 3) | 100K+ ops/sec | <2ms |
| PageRank (10K nodes) | - | ~50ms |

See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks and optimization guides.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution Steps

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`mix test`)
5. Ensure formatting (`mix format`)
6. Commit with descriptive messages
7. Push and open a Pull Request

### Development Setup

```bash
# Clone the repository
git clone https://github.com/justin4957/Grapple.git
cd grapple

# Install dependencies
mix deps.get

# Run tests
mix test

# Run with coverage
mix coveralls

# Generate documentation
mix docs

# Start interactive shell
iex -S mix
```

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for our detailed development roadmap.

### Upcoming Features
- 🎨 **Web Dashboard**: Phoenix LiveView visualization interface
- 🔍 **Full-Text Search**: Advanced text search capabilities
- 🔐 **Authentication**: RBAC and security features
- 📊 **Advanced Analytics**: More graph algorithms (Louvain, eigenvector centrality)
- 🌍 **Multi-Language Drivers**: Python, JavaScript, Go, Rust
- 📈 **Time-Series Support**: Temporal graph queries

## 📊 Project Stats

- **Language**: Elixir 1.18+
- **Lines of Code**: ~10,000
- **Test Coverage**: 90%+
- **Tests**: 212 (20 doctests, 13 property-based, 179 unit/integration)
- **Dependencies**: Minimal (Jason, ExDoc, testing tools)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Elixir](https://elixir-lang.org/) and the BEAM VM
- Inspired by [Neo4j](https://neo4j.com/), [TigerGraph](https://www.tigergraph.com/), and other graph databases
- Thanks to all [contributors](https://github.com/justin4957/Grapple/graphs/contributors)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/justin4957/Grapple/issues)
- **Discussions**: [GitHub Discussions](https://github.com/justin4957/Grapple/discussions)
- **Documentation**: [Guides](guides/) and [API Docs](https://hexdocs.pm/grapple)

---

**Made with ❤️ by the Grapple team**

[Get Started](guides/tutorials/quick-start.md) • [Documentation](GUIDE.md) • [Examples](guides/examples/) • [Contributing](CONTRIBUTING.md)
