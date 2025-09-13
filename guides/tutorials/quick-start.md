# 5-Minute Quick Start

Get up and running with Grapple in just 5 minutes.

## Installation

```bash
git clone <your-repo>
cd grapple
mix deps.get
mix compile
```

## Basic Usage

```elixir
# Start the system
{:ok, _} = Grapple.start()

# Create nodes
{:ok, node1} = Grapple.create_node(%{name: "Alice", age: 30})
{:ok, node2} = Grapple.create_node(%{name: "Bob", age: 25})

# Create relationships
{:ok, edge} = Grapple.create_edge(node1, node2, "friends", %{since: "2020"})

# Query the graph
friends = Grapple.get_neighbors(node1)
```

## CLI Interface

```bash
# Start interactive shell
mix run -e "Grapple.CLI.Shell.start()"

# Basic commands
grapple> create_node name:"Alice" age:30
grapple> create_node name:"Bob" age:25
grapple> create_edge 1 2 "friends" since:"2020"
grapple> neighbors 1
grapple> visualize
```

## Next Steps

- Read the [Complete User Guide](../GUIDE.md) for detailed features
- Try the [Social Network Example](../examples/social-network.md)
- Learn about [Performance Optimization](../advanced/performance.md)