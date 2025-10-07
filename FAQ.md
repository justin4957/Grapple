# Frequently Asked Questions (FAQ)

Common questions about Grapple graph database.

## Table of Contents

- [General Questions](#general-questions)
- [Installation & Setup](#installation--setup)
- [Performance](#performance)
- [Data Management](#data-management)
- [Distributed Features](#distributed-features)
- [Development](#development)

## General Questions

### What is Grapple?

Grapple is a distributed graph database implemented in Elixir, designed for in-memory graph operations with distributed capabilities. It features property indexing, query optimization, and a three-tier storage system (ETS, Mnesia, DETS).

### Why use Grapple?

Grapple is ideal when you need:
- Fast in-memory graph operations
- Property-based node and edge queries
- Distributed clustering capabilities
- Elixir/Erlang ecosystem integration
- Low-latency graph traversals

### How does Grapple compare to Neo4j or other graph databases?

**Strengths:**
- Native Elixir integration
- In-memory performance
- Built-in distributed features
- Lightweight and embeddable

**Trade-offs:**
- Smaller feature set than enterprise solutions
- Limited query language (compared to Cypher)
- Less mature ecosystem
- Better suited for medium-sized graphs

### Is Grapple production-ready?

Grapple is currently in active development (v0.1.0). While core features are functional and tested, it's recommended for:
- Development and testing environments
- Proof-of-concept projects
- Non-critical applications
- Learning and experimentation

For production use, thoroughly test with your specific use case and workload.

### What license is Grapple under?

Check the LICENSE file in the repository for current licensing information.

## Installation & Setup

### What versions of Elixir and Erlang do I need?

- **Elixir**: 1.18 or later
- **Erlang/OTP**: 27 or later

Check your versions:
```bash
elixir --version
```

### How do I install Grapple?

Add to your `mix.exs`:
```elixir
def deps do
  [
    {:grapple, "~> 0.1.0"}
  ]
end
```

Then run:
```bash
mix deps.get
```

### Can I use Grapple without distributed features?

Yes! Distributed features are optional. By default, Grapple runs in single-node mode. Enable distributed mode when needed:

```elixir
# In config/config.exs
config :grapple, distributed: true
```

### How do I set up a development environment?

See our [CONTRIBUTING.md](CONTRIBUTING.md#development-setup) guide or run:
```bash
./scripts/dev-setup.sh
```

## Performance

### How fast is Grapple?

Performance depends on your use case, but typical benchmarks show:
- **Node creation**: ~300K ops/sec
- **Property lookup**: O(1) with indexing
- **Graph traversal**: ~1M nodes/sec (depth 1-2)
- **Memory usage**: ~86 words/node, ~32 words/edge

See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks.

### How much memory does Grapple use?

Approximate memory usage:
- **Small graph** (1K nodes): ~1-2 MB
- **Medium graph** (100K nodes): ~100 MB
- **Large graph** (1M nodes): ~880 MB

Use profiling tools to analyze your specific usage:
```elixir
Grapple.Performance.Profiler.analyze_memory_usage()
```

### When should I use distributed mode?

Consider distributed mode when:
- Dataset exceeds single-node memory (>4GB)
- Need high availability
- Require fault tolerance
- Want to distribute load across nodes

For smaller graphs (<1M nodes), single-node mode is usually sufficient.

### How can I optimize query performance?

1. **Use Property Indexing**: Properties are automatically indexed
2. **Limit Traversal Depth**: Use shallow traversals when possible
3. **Filter Early**: Apply filters before traversals
4. **Batch Operations**: Group related operations
5. **Monitor Performance**: Use profiling tools

See [Performance Guide](guides/advanced/performance.md) for more.

## Data Management

### How do I back up my data?

For ETS (in-memory) data:
```elixir
# Periodic snapshots recommended
nodes = Grapple.list_nodes()
edges = Grapple.list_edges()
# Save to file or database
```

For Mnesia/DETS data:
```bash
# Mnesia backup
:mnesia.backup("backup.mnesia")
```

### Can I import data from other graph databases?

Not directly, but you can write import scripts:

```elixir
# Example: Import from CSV
File.stream!("nodes.csv")
|> CSV.decode!()
|> Enum.each(fn [id, name, type] ->
  Grapple.create_node(%{
    external_id: id,
    name: name,
    type: type
  })
end)
```

### How do I export data?

```elixir
# Export to JSON
nodes = Grapple.list_nodes()
edges = Grapple.list_edges()

data = %{
  nodes: nodes,
  edges: edges
}

File.write!("export.json", Jason.encode!(data))
```

### What's the maximum graph size?

Theoretical limits:
- **Nodes**: Limited by available memory
- **Edges**: Limited by available memory
- **Properties**: No hard limit per node/edge

Practical limits depend on your hardware:
- 8GB RAM: ~5-10M nodes
- 16GB RAM: ~10-20M nodes
- 32GB RAM: ~20-40M nodes

For larger graphs, use distributed mode across multiple nodes.

### How do I delete all data?

```elixir
# Delete all nodes (this also deletes associated edges)
Grapple.list_nodes()
|> Enum.each(&Grapple.delete_node(&1.id))

# Or restart the application (loses all ETS data)
Application.stop(:grapple)
Application.start(:grapple)
```

## Distributed Features

### How do I set up a cluster?

1. Start nodes with proper names:
```bash
# Node 1
iex --name node1@hostname --cookie secret

# Node 2
iex --name node2@hostname --cookie secret
```

2. Enable distributed mode:
```elixir
Application.put_env(:grapple, :distributed, true)
```

3. Join cluster:
```elixir
# On node2
Grapple.Distributed.ClusterManager.join_cluster(:node1@hostname)
```

See [Distributed Mode Guide](README_DISTRIBUTED.md) for details.

### Do I need special network configuration?

Basic requirements:
- Nodes must be able to reach each other
- Port 4369 (EPMD) must be open
- Erlang distribution ports must be open (random high ports by default)
- Same cookie on all nodes

For production, configure firewall rules appropriately.

### What happens if a node fails?

Grapple includes basic fault tolerance:
- Health monitoring detects failures
- Automatic recovery attempts
- Data replication (if configured)
- Partition redistribution

However, full high-availability requires proper configuration and testing.

### Can I run Grapple in Kubernetes?

Yes, but requires careful configuration:
- Use StatefulSets for stable network identities
- Configure proper service discovery
- Set appropriate resource limits
- Plan for data persistence

See community examples for Kubernetes deployments.

## Development

### How do I contribute to Grapple?

See our [CONTRIBUTING.md](CONTRIBUTING.md) guide for:
- Development setup
- Coding standards
- Pull request process
- Testing guidelines

### Where can I report bugs?

Create an issue on GitHub:
https://github.com/justin4957/Grapple/issues

Please include:
- Elixir/Erlang versions
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or errors

### How do I run tests?

```bash
# All tests
mix test

# With coverage
mix coveralls

# Specific test file
mix test test/grapple/some_test.exs

# Integration tests
mix test --only integration
```

See [TESTING.md](TESTING.md) for comprehensive testing guide.

### Can I use Grapple in production?

Grapple is early-stage software. Recommendations:
- ✅ Development and testing
- ✅ Proof-of-concept projects
- ⚠️ Production (with thorough testing)
- ❌ Mission-critical systems (not yet)

Always test with your specific workload before production use.

### How do I enable debug logging?

```elixir
# In config/dev.exs or config/test.exs
config :logger, level: :debug

# At runtime
Logger.configure(level: :debug)
```

### What IDE/editor should I use?

Popular choices:
- **VS Code**: ElixirLS extension
- **IntelliJ IDEA**: Elixir plugin
- **Vim/Neovim**: vim-elixir plugin
- **Emacs**: elixir-mode

All work well with Grapple.

## Troubleshooting

### My tests are failing intermittently

Common causes:
- Async tests with shared state
- Timing issues
- ETS tables not cleaned between tests

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#testing-issues) for solutions.

### I'm getting `:node_not_found` errors

Check:
- Node ID is correct
- Node exists: `Grapple.get_node(id)`
- Node wasn't deleted

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#runtime-errors) for more.

### Memory usage is growing

Solutions:
- Delete unused data
- Use profiling tools
- Enable lifecycle management
- Consider distributed mode

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#memory-issues) for details.

### Cluster nodes won't connect

Common issues:
- Cookie mismatch
- Network/firewall issues
- Node names not configured
- EPMD not running

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#distributed-mode-issues) for solutions.

## Additional Resources

- [Complete User Guide](GUIDE.md)
- [Performance Monitoring](PERFORMANCE.md)
- [Testing Guide](TESTING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Architecture Overview](guides/advanced/architecture.md)
- [Quick Start Tutorial](guides/tutorials/quick-start.md)

## Still Have Questions?

- **Documentation**: Check our comprehensive guides
- **Issues**: Search or create an issue on GitHub
- **Community**: Join discussions on GitHub Discussions

---

Don't see your question? [Open an issue](https://github.com/justin4957/Grapple/issues) and we'll add it to this FAQ!
