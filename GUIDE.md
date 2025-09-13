# Complete User Guide

Comprehensive guide to using Grapple graph database.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Concepts](#core-concepts)
3. [API Reference](#api-reference)
4. [Query Language](#query-language)
5. [CLI Interface](#cli-interface)
6. [Performance Optimization](#performance-optimization)
7. [Distributed Features](#distributed-features)

## Getting Started

### Installation

```bash
git clone <repository>
cd grapple
mix deps.get
mix compile
```

### Basic Usage

```elixir
# Start Grapple
{:ok, _} = Grapple.start()

# Create your first graph
{:ok, alice} = Grapple.create_node(%{name: "Alice", age: 30})
{:ok, bob} = Grapple.create_node(%{name: "Bob", age: 25})
{:ok, edge} = Grapple.create_edge(alice, bob, "friends")

# Query the graph
friends = Grapple.get_neighbors(alice)
IO.inspect(friends)
```

## Core Concepts

### Nodes
Nodes represent entities in your graph with arbitrary properties:

```elixir
{:ok, user} = Grapple.create_node(%{
  name: "Alice Johnson",
  email: "alice@example.com",
  age: 30,
  city: "San Francisco"
})
```

### Edges
Edges represent relationships between nodes:

```elixir
{:ok, friendship} = Grapple.create_edge(alice_id, bob_id, "friends", %{
  since: "2020-01-15",
  strength: "strong"
})
```

### Properties
Both nodes and edges can have arbitrary key-value properties:

- **Indexed Properties**: Automatically indexed for fast queries
- **Typed Values**: Strings, numbers, booleans, lists, maps
- **Dynamic Schema**: No predefined schema required

## API Reference

### Node Operations

```elixir
# Create node
{:ok, id} = Grapple.create_node(%{name: "Alice"})

# Get node
{:ok, node} = Grapple.get_node(id)

# Update node
{:ok, updated} = Grapple.update_node(id, %{age: 31})

# Delete node
:ok = Grapple.delete_node(id)

# List all nodes
nodes = Grapple.list_nodes()

# Find nodes by property
users = Grapple.find_nodes(%{type: "user"})
```

### Edge Operations

```elixir
# Create edge
{:ok, edge_id} = Grapple.create_edge(from_id, to_id, "follows")

# Get edge
{:ok, edge} = Grapple.get_edge(edge_id)

# Update edge
{:ok, updated} = Grapple.update_edge(edge_id, %{weight: 0.8})

# Delete edge
:ok = Grapple.delete_edge(edge_id)

# List all edges
edges = Grapple.list_edges()
```

### Graph Traversal

```elixir
# Get direct neighbors
neighbors = Grapple.get_neighbors(node_id)

# Get neighbors by edge type
friends = Grapple.get_neighbors(node_id, edge_type: "friends")

# Traverse with depth limit
network = Grapple.traverse(node_id, depth: 3)

# Find path between nodes
path = Grapple.find_path(start_id, end_id)

# Find shortest path
shortest = Grapple.shortest_path(start_id, end_id)
```

## Query Language

Grapple supports a SQL-like query language for complex graph operations:

### Basic Patterns

```sql
-- Find all users
MATCH (u {type: "user"}) RETURN u

-- Find friendships
MATCH (a)-[:friends]-(b) RETURN a, b

-- Path queries
MATCH (a)-[:friends*1..3]-(b) WHERE a.name = "Alice" RETURN b
```

### Filtering

```sql
-- Property filters
MATCH (u {type: "user"}) WHERE u.age > 25 RETURN u

-- Multiple conditions
MATCH (u) WHERE u.age > 25 AND u.city = "San Francisco" RETURN u

-- Pattern matching
MATCH (a)-[r:friends]-(b) WHERE r.strength = "strong" RETURN a, b
```

### Aggregation

```sql
-- Count nodes
MATCH (u {type: "user"}) RETURN count(u)

-- Group by property
MATCH (u {type: "user"}) RETURN u.city, count(u)

-- Average, sum, etc.
MATCH (u {type: "user"}) RETURN avg(u.age), max(u.age)
```

## CLI Interface

### Starting the CLI

```bash
mix run -e "Grapple.CLI.Shell.start()"
```

### Available Commands

```bash
# Node operations
create_node name:"Alice" age:30
get_node 1
update_node 1 city:"New York"
delete_node 1
list_nodes
find_nodes type:"user"

# Edge operations
create_edge 1 2 "friends" since:"2020"
get_edge 1
update_edge 1 strength:"strong"
delete_edge 1
list_edges

# Graph operations
neighbors 1
neighbors 1 friends
traverse 1 depth:2
path 1 5
shortest_path 1 5

# Visualization
visualize
visualize center:1 depth:2
ascii_render

# System operations
stats
help
quit
```

### Autocomplete

The CLI includes intelligent autocomplete for:
- Command names
- Node and edge IDs
- Property names
- Edge types

## Performance Optimization

### Storage Tiers

Grapple uses a three-tier storage architecture:

1. **ETS (Hot)**: In-memory, high-performance access
2. **Mnesia (Warm)**: Distributed, transactional storage
3. **DETS (Cold)**: Persistent disk storage

### Optimization Tips

```elixir
# Use appropriate data classification
Grapple.LifecycleManager.classify_data(key, :ephemeral, %{
  ttl: 3600,  # 1 hour
  access_pattern: :frequent
})

# Batch operations for better performance
Grapple.transaction(fn ->
  Enum.each(nodes, &Grapple.create_node/1)
end)

# Limit traversal depth
results = Grapple.traverse(node_id, depth: 3, limit: 1000)
```

### Monitoring

```elixir
# Check performance statistics
stats = Grapple.stats()
%{
  nodes: 10000,
  edges: 25000,
  memory_mb: 120,
  operations_per_sec: 50000
}

# Detailed performance metrics
perf = Grapple.performance_stats()
```

## Distributed Features

### Cluster Setup

```elixir
# Configure cluster discovery
config :grapple, :distributed,
  discovery_method: :mdns,
  cluster_name: "grapple_cluster",
  node_name: "grapple@node1.local"

# Start distributed mode
Grapple.Distributed.start()
```

### Data Placement

```elixir
# Configure placement strategy
Grapple.PlacementEngine.configure(%{
  strategy: :performance_optimized,
  replication_factor: 3,
  locality_preference: true
})
```

### Replication

```elixir
# Configure replication
config :grapple, :replication,
  strategy: :async,
  consistency_level: :eventual,
  conflict_resolution: :last_write_wins
```

## Advanced Topics

### Custom Storage Backends

```elixir
defmodule MyApp.CustomStorage do
  @behaviour Grapple.Storage.Backend
  
  # Implement required callbacks
  def create_node(properties, opts), do: ...
  def get_node(id, opts), do: ...
  # ... other callbacks
end

# Register custom backend
Grapple.register_storage_backend(:custom, MyApp.CustomStorage)
```

### Query Extensions

```elixir
defmodule MyApp.CustomQueries do
  def complex_analytics(graph_subset) do
    # Custom analytics implementation
  end
end
```

### Event Hooks

```elixir
# Register event handlers
Grapple.Events.subscribe(:node_created, fn node ->
  Logger.info("New node created: #{node.id}")
end)
```

## Error Handling

### Common Errors

```elixir
# Node not found
{:error, :not_found} = Grapple.get_node(999)

# Invalid edge (nodes don't exist)
{:error, :invalid_nodes} = Grapple.create_edge(1, 999, "friends")

# Concurrent modification
{:error, :version_conflict} = Grapple.update_node(1, %{name: "Alice"})
```

### Best Practices

1. Always handle error tuples
2. Use transactions for multi-step operations
3. Validate input data
4. Monitor system health
5. Implement retry logic for distributed operations

## Examples

See the [Social Network Example](guides/examples/social-network.md) for a complete working example.

## Getting Help

- Use `help` command in the CLI
- Check the [Performance Guide](guides/advanced/performance.md)
- Review the [Architecture Overview](guides/advanced/architecture.md)
- Read about [Distributed Features](README_DISTRIBUTED.md)