# Graph Analytics Example

This example demonstrates using Grapple's advanced analytics capabilities to analyze graph structures and extract insights.

## Overview

Grapple provides powerful analytics algorithms for:
- **Centrality Analysis**: Identify important nodes (PageRank, betweenness, closeness)
- **Community Detection**: Find clusters and communities (connected components, clustering coefficient)
- **Graph Metrics**: Calculate graph properties (density, diameter, degree distribution)

## Setup

```elixir
# Start Grapple
{:ok, _} = Grapple.start()

# Create a sample social network
users = [
  %{name: "Alice", role: "influencer"},
  %{name: "Bob", role: "connector"},
  %{name: "Charlie", role: "user"},
  %{name: "Diana", role: "user"},
  %{name: "Eve", role: "user"},
  %{name: "Frank", role: "user"}
]

user_ids = Enum.map(users, fn user ->
  {:ok, id} = Grapple.create_node(user)
  id
end)

[alice, bob, charlie, diana, eve, frank] = user_ids
```

## Centrality Analysis

### PageRank: Finding Influential Nodes

PageRank identifies the most important nodes based on their connections and the importance of nodes linking to them.

```elixir
# Create a network structure
# Alice is highly connected (hub)
Grapple.create_edge(bob, alice, "follows")
Grapple.create_edge(charlie, alice, "follows")
Grapple.create_edge(diana, alice, "follows")
Grapple.create_edge(eve, alice, "follows")

# Bob connects communities
Grapple.create_edge(alice, bob, "follows")
Grapple.create_edge(bob, charlie, "follows")
Grapple.create_edge(bob, frank, "follows")

# Calculate PageRank
{:ok, ranks} = Grapple.Analytics.pagerank()

# Find most influential user
{top_user_id, rank} = Enum.max_by(ranks, fn {_id, rank} -> rank end)
IO.puts("Most influential user has PageRank: #{rank}")
```

**Custom PageRank Parameters:**

```elixir
# Adjust damping factor and convergence
{:ok, ranks} = Grapple.Analytics.pagerank(
  damping_factor: 0.85,     # Probability of following a link (default: 0.85)
  max_iterations: 100,      # Maximum iterations (default: 100)
  tolerance: 0.0001         # Convergence threshold (default: 0.0001)
)
```

### Betweenness Centrality: Finding Bridges

Betweenness centrality identifies nodes that act as bridges between different parts of the network.

```elixir
# Calculate betweenness for all nodes
{:ok, betweenness} = Grapple.Analytics.betweenness_centrality()

# Find bridge nodes (high betweenness)
bridges = Enum.filter(betweenness, fn {_id, score} -> score > 0.1 end)
IO.puts("Found #{length(bridges)} bridge nodes")
```

**Use Cases:**
- Identify key connectors in social networks
- Find critical infrastructure nodes
- Detect information bottlenecks

### Closeness Centrality: Measuring Accessibility

Closeness centrality measures how quickly a node can reach all other nodes.

```elixir
# Calculate closeness for specific nodes
{:ok, alice_closeness} = Grapple.Analytics.closeness_centrality(alice)
{:ok, bob_closeness} = Grapple.Analytics.closeness_centrality(bob)

if alice_closeness > bob_closeness do
  IO.puts("Alice is more centrally located in the network")
else
  IO.puts("Bob is more centrally located in the network")
end
```

## Community Detection

### Connected Components: Finding Clusters

Identify separate communities or disconnected groups in the network.

```elixir
# Calculate connected components
{:ok, components} = Grapple.Analytics.connected_components()

# Components are sorted by size (largest first)
IO.puts("Found #{length(components)} communities")

# Examine largest community
largest_component = hd(components)
IO.puts("Largest community has #{length(largest_component)} members")

# Find isolated users (components of size 1)
isolated = Enum.filter(components, fn component -> length(component) == 1 end)
IO.puts("Found #{length(isolated)} isolated users")
```

### Clustering Coefficient: Measuring Interconnectedness

The clustering coefficient measures how tightly knit a network is.

```elixir
# Global clustering coefficient
{:ok, global_coefficient} = Grapple.Analytics.clustering_coefficient()
IO.puts("Network clustering: #{Float.round(global_coefficient, 3)}")

# Interpret results:
# 0.0 = Linear network (no triangles)
# 0.5 = Moderately clustered
# 1.0 = Fully connected cliques
```

**Local Clustering Coefficient:**

```elixir
# Measure how clustered a specific node's neighborhood is
{:ok, alice_clustering} = Grapple.Analytics.local_clustering_coefficient(alice)

if alice_clustering > 0.7 do
  IO.puts("Alice's friends are well connected (tight-knit group)")
else
  IO.puts("Alice connects diverse groups (spanning structural holes)")
end
```

## Graph Metrics

### Graph Density: Network Completeness

Density measures what fraction of possible connections exist.

```elixir
{:ok, density} = Grapple.Analytics.graph_density()
IO.puts("Graph density: #{Float.round(density, 3)}")

# Interpretation:
# 0.0 = No connections (empty graph)
# 0.5 = Half of possible connections exist
# 1.0 = Complete graph (all possible connections)
```

### Graph Diameter: Maximum Distance

The diameter is the longest shortest path in the network.

```elixir
{:ok, diameter} = Grapple.Analytics.graph_diameter()
IO.puts("Network diameter: #{diameter} hops")

# Smaller diameter = more tightly connected network
# Larger diameter = more spread out network
```

### Degree Distribution: Connection Patterns

Analyze how connections are distributed across nodes.

```elixir
{:ok, stats} = Grapple.Analytics.degree_distribution()

IO.puts("Degree Statistics:")
IO.puts("  Min: #{stats.min}")
IO.puts("  Max: #{stats.max}")
IO.puts("  Mean: #{Float.round(stats.mean, 2)}")
IO.puts("  Median: #{Float.round(stats.median, 2)}")
IO.puts("  Std Dev: #{Float.round(stats.std_dev, 2)}")

# Detect network topology
if stats.max > stats.mean * 3 do
  IO.puts("Network has hub nodes (scale-free topology)")
else
  IO.puts("Network has uniform connectivity")
end
```

### Connectivity Metrics: Network Structure

Comprehensive analysis of network connectivity.

```elixir
{:ok, metrics} = Grapple.Analytics.connectivity_metrics()

IO.puts("Connectivity Analysis:")
IO.puts("  Connected: #{metrics.is_connected}")
IO.puts("  Components: #{metrics.component_count}")
IO.puts("  Largest component: #{metrics.largest_component_size} nodes")

# Use cases:
# - Verify network is fully connected
# - Monitor network fragmentation
# - Identify isolated subgraphs
```

### Average Path Length: Network Efficiency

Measure the typical distance between nodes.

```elixir
{:ok, avg_length} = Grapple.Analytics.average_path_length()
IO.puts("Average path length: #{Float.round(avg_length, 2)} hops")

# Smaller values indicate more efficient networks
# Related to "six degrees of separation" concept
```

## Complete Analysis: Putting It All Together

Get a comprehensive summary of all analytics:

```elixir
{:ok, summary} = Grapple.Analytics.summary()

IO.inspect(summary, label: "Graph Analytics Summary")

# Example output:
# %{
#   density: 0.25,
#   diameter: 3,
#   component_count: 1,
#   components: [[1, 2, 3, 4, 5, 6]],
#   clustering_coefficient: 0.45,
#   degree_distribution: %{
#     min: 1,
#     max: 5,
#     mean: 2.67,
#     median: 2.0,
#     std_dev: 1.21
#   }
# }
```

## Real-World Use Cases

### 1. Social Network Analysis

```elixir
# Identify influencers
{:ok, pageranks} = Grapple.Analytics.pagerank()
influencers =
  pageranks
  |> Enum.sort_by(fn {_id, rank} -> -rank end)
  |> Enum.take(10)

# Find community leaders (high betweenness)
{:ok, betweenness} = Grapple.Analytics.betweenness_centrality()
leaders =
  betweenness
  |> Enum.sort_by(fn {_id, score} -> -score end)
  |> Enum.take(10)

# Detect communities
{:ok, communities} = Grapple.Analytics.connected_components()
```

### 2. Infrastructure Analysis

```elixir
# Find critical nodes in network infrastructure
{:ok, betweenness} = Grapple.Analytics.betweenness_centrality()
critical_nodes = Enum.filter(betweenness, fn {_id, score} -> score > 0.5 end)

# Verify network resilience
{:ok, connectivity} = Grapple.Analytics.connectivity_metrics()
if connectivity.is_connected do
  IO.puts("Infrastructure is fully connected")
else
  IO.puts("Warning: #{connectivity.component_count} isolated segments detected")
end
```

### 3. Recommendation Systems

```elixir
# Find users with similar connectivity patterns
{:ok, alice_clustering} = Grapple.Analytics.local_clustering_coefficient(alice)
{:ok, bob_clustering} = Grapple.Analytics.local_clustering_coefficient(bob)

similarity = 1 - abs(alice_clustering - bob_clustering)
if similarity > 0.8 do
  IO.puts("Alice and Bob have similar social patterns - recommend connection")
end

# Find users in same community for recommendations
{:ok, components} = Grapple.Analytics.connected_components()
alice_community = Enum.find(components, fn comp -> alice in comp end)
recommendations = alice_community -- [alice]
```

## Performance Considerations

For large graphs, analytics algorithms can be computationally intensive:

- **PageRank**: O(iterations × edges) - typically converges in 20-50 iterations
- **Betweenness**: O(nodes × edges) - most expensive algorithm
- **Connected Components**: O(nodes + edges) - very efficient with Union-Find
- **Clustering Coefficient**: O(nodes × degree²) - depends on node connectivity

Tips for large graphs:
1. Use `max_iterations` and `tolerance` to control PageRank convergence
2. Calculate betweenness only when needed (it's the slowest)
3. Cache results and recalculate only when graph changes significantly
4. Consider sampling for approximate analytics on very large graphs

## API Reference

All analytics functions return `{:ok, result}` or `{:error, reason}` tuples.

### Centrality
- `Grapple.Analytics.pagerank(opts \\ [])` - PageRank scores
- `Grapple.Analytics.betweenness_centrality()` - Betweenness centrality scores
- `Grapple.Analytics.closeness_centrality(node_id)` - Closeness for specific node

### Community
- `Grapple.Analytics.connected_components()` - List of components
- `Grapple.Analytics.clustering_coefficient()` - Global clustering coefficient
- `Grapple.Analytics.local_clustering_coefficient(node_id)` - Local clustering

### Metrics
- `Grapple.Analytics.graph_density()` - Graph density (0.0-1.0)
- `Grapple.Analytics.graph_diameter()` - Maximum shortest path length
- `Grapple.Analytics.degree_distribution()` - Degree statistics
- `Grapple.Analytics.average_path_length()` - Mean shortest path length
- `Grapple.Analytics.connectivity_metrics()` - Connectivity analysis
- `Grapple.Analytics.summary()` - All metrics in one call
