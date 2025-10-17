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

Centrality algorithms help identify the most important nodes in a network based on different criteria.

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

### Eigenvector Centrality: Influence by Association

Eigenvector centrality identifies nodes that are connected to other influential nodes. A node is important if it's connected to other important nodes.

```elixir
# Calculate eigenvector centrality
{:ok, centralities} = Grapple.Analytics.eigenvector_centrality()

# Find most influential nodes
top_nodes =
  centralities
  |> Enum.sort_by(fn {_id, centrality} -> -centrality end)
  |> Enum.take(5)

IO.puts("Top 5 nodes by eigenvector centrality:")
Enum.each(top_nodes, fn {node_id, centrality} ->
  IO.puts("  Node #{node_id}: #{Float.round(centrality, 6)}")
end)
```

**Custom Options:**

```elixir
# Adjust convergence parameters
{:ok, centralities} = Grapple.Analytics.eigenvector_centrality(
  max_iterations: 100,    # Maximum iterations (default: 100)
  tolerance: 0.0001       # Convergence threshold (default: 0.0001)
)
```

**Use Cases:**
- Identify influential nodes in social networks
- Find important papers in citation networks
- Detect authoritative web pages
- Analyze protein interaction networks

**Difference from PageRank:**
- PageRank includes damping factor (random jumps)
- Eigenvector centrality is "purer" - only based on neighbor importance
- Both use power iteration, but Eigenvector uses L2 normalization

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

### Louvain Algorithm: Advanced Community Detection

The Louvain algorithm detects communities by optimizing modularity, which measures the density of links within communities compared to random networks.

```elixir
# Detect communities using Louvain algorithm
{:ok, communities} = Grapple.Analytics.louvain_communities()

# Group nodes by their community
community_groups =
  communities
  |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

IO.puts("Detected #{map_size(community_groups)} communities")

# Analyze each community
Enum.each(community_groups, fn {comm_id, node_ids} ->
  IO.puts("Community #{comm_id}: #{length(node_ids)} members")
  IO.puts("  Nodes: #{Enum.join(Enum.take(node_ids, 5), ", ")}...")
end)
```

**Use Cases:**
- Social network analysis (friend groups, interest clusters)
- Biological networks (protein complexes, metabolic pathways)
- Recommendation systems (user segments)
- Network visualization (group nodes by community)

**Algorithm Details:**
- Two-phase optimization: local moves + network aggregation
- Greedy modularity maximization
- Fast and scalable: O(n log n) complexity
- Produces hierarchical community structure

### K-Core Decomposition: Finding Dense Subgraphs

K-core decomposition finds the most tightly connected subgraphs by identifying cores where every node has at least k connections.

```elixir
# Perform k-core decomposition
{:ok, cores} = Grapple.Analytics.k_core_decomposition()

# Find maximum core number
max_core = cores |> Map.values() |> Enum.max()
IO.puts("Maximum core number: #{max_core}")

# Find nodes in the highest core (most connected)
highest_core_nodes =
  cores
  |> Enum.filter(fn {_id, core} -> core == max_core end)
  |> Enum.map(&elem(&1, 0))

IO.puts("Most densely connected nodes (#{max_core}-core):")
IO.puts("  #{Enum.join(highest_core_nodes, ", ")}")

# Analyze core distribution
core_distribution =
  cores
  |> Enum.group_by(&elem(&1, 1))
  |> Enum.sort_by(&elem(&1, 0), :desc)

Enum.each(core_distribution, fn {k, nodes} ->
  IO.puts("  #{k}-core: #{length(nodes)} nodes")
end)
```

**Use Cases:**
- Find influential groups in social networks
- Identify resilient network structures
- Network visualization (layout by core number)
- Spam detection (low core = peripheral)
- Infrastructure analysis (critical subnetworks)

**Interpretation:**
- **High core number**: Node is part of densely connected group
- **Low core number**: Peripheral node with few connections
- **Core 0**: Isolated nodes
- **Core 1**: Nodes with only 1 connection

### Triangle Counting: Network Cohesion

Count how many triangles each node participates in. Triangles indicate strong local clustering and cohesion.

```elixir
# Count triangles for each node
{:ok, triangles} = Grapple.Analytics.triangle_count()

# Calculate total triangles in graph
total_triangles = triangles |> Map.values() |> Enum.sum() |> div(3)
IO.puts("Total triangles in network: #{total_triangles}")

# Find nodes with most triangle participation
top_triangle_nodes =
  triangles
  |> Enum.sort_by(&elem(&1, 1), :desc)
  |> Enum.take(10)

IO.puts("Top 10 nodes by triangle participation:")
Enum.each(top_triangle_nodes, fn {node_id, count} ->
  IO.puts("  Node #{node_id}: #{count} triangles")
end)

# Identify nodes with no triangles (tree-like connections)
no_triangles =
  triangles
  |> Enum.filter(fn {_id, count} -> count == 0 end)
  |> length()

IO.puts("Nodes with no triangles: #{no_triangles}")
```

**Use Cases:**
- Spam detection (spammers have few triangles)
- Community strength measurement
- Network resilience analysis
- Social network authenticity verification
- Clustering coefficient calculation

**Relationship to Clustering:**
- High triangle count = strong local clustering
- Triangle count / possible triangles = local clustering coefficient
- Complements global clustering coefficient

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

### Algorithm Complexity

**Centrality Algorithms:**
- **PageRank**: O(iterations × edges) - typically converges in 20-50 iterations
- **Eigenvector Centrality**: O(iterations × edges) - similar to PageRank
- **Betweenness**: O(nodes × edges) - most expensive algorithm
- **Closeness**: O(nodes × edges) - requires BFS from each node

**Community Detection:**
- **Connected Components**: O(nodes + edges) - very efficient with Union-Find
- **Louvain**: O(nodes × log(nodes)) - fast and scalable
- **K-Core**: O(nodes + edges) - linear time with bucket sorting
- **Triangle Counting**: O(nodes × degree²) - depends on network density
- **Clustering Coefficient**: O(nodes × degree²) - depends on node connectivity

### Optimization Tips

1. **PageRank & Eigenvector Centrality**:
   - Use `max_iterations` and `tolerance` to control convergence
   - Start with lower iterations for quick approximations
   - These algorithms are parallelizable for very large graphs

2. **Betweenness Centrality**:
   - Most computationally expensive - calculate only when needed
   - Consider approximation algorithms for graphs > 10,000 nodes
   - Can be sampled (calculate for subset of nodes)

3. **Community Detection**:
   - Louvain is fast even for large graphs (millions of nodes)
   - K-core is very efficient - use for quick network structure analysis
   - Connected components is fastest - always run first for basic structure

4. **Triangle Counting**:
   - Performance depends on network density
   - Works well for sparse graphs
   - Consider node-iterator or edge-iterator based on graph structure

5. **General Optimization**:
   - Cache results and recalculate only when graph changes significantly
   - Run analyses during off-peak hours for large graphs
   - Consider incremental updates for dynamic graphs
   - Use sampling for approximate analytics on very large graphs

### When to Use Each Algorithm

**Quick Analysis (< 1 second for moderate graphs)**:
- Connected Components
- K-Core Decomposition
- Graph Density
- Degree Distribution

**Medium Analysis (seconds to minutes)**:
- PageRank
- Eigenvector Centrality
- Louvain Communities
- Triangle Counting
- Clustering Coefficient

**Intensive Analysis (minutes to hours for large graphs)**:
- Betweenness Centrality
- Closeness Centrality (all nodes)
- Graph Diameter

## API Reference

All analytics functions return `{:ok, result}` or `{:error, reason}` tuples.

### Centrality (`Grapple.Analytics.Centrality`)
- `pagerank(opts \\ [])` - PageRank scores for all nodes
  - Options: `:damping_factor`, `:max_iterations`, `:tolerance`
  - Returns: `{:ok, %{node_id => score}}`

- `eigenvector_centrality(opts \\ [])` - Eigenvector centrality scores
  - Options: `:max_iterations`, `:tolerance`
  - Returns: `{:ok, %{node_id => centrality}}`

- `betweenness_centrality()` - Betweenness centrality scores for all nodes
  - Returns: `{:ok, %{node_id => score}}`

- `closeness_centrality(node_id)` - Closeness centrality for specific node
  - Returns: `{:ok, closeness_value}`

### Community (`Grapple.Analytics.Community`)
- `connected_components()` - Find all connected components
  - Returns: `{:ok, [[node_ids], ...]}` (sorted by size, descending)

- `louvain_communities()` - Detect communities using Louvain algorithm
  - Returns: `{:ok, %{node_id => community_id}}`

- `k_core_decomposition()` - Compute k-core numbers for all nodes
  - Returns: `{:ok, %{node_id => core_number}}`

- `triangle_count()` - Count triangles for each node
  - Returns: `{:ok, %{node_id => triangle_count}}`

- `clustering_coefficient()` - Global clustering coefficient
  - Returns: `{:ok, coefficient}`

- `local_clustering_coefficient(node_id)` - Local clustering for specific node
  - Returns: `{:ok, coefficient}`

### Metrics (`Grapple.Analytics.Metrics`)
- `graph_density()` - Graph density (0.0-1.0)
  - Returns: `{:ok, density}`

- `graph_diameter()` - Maximum shortest path length
  - Returns: `{:ok, diameter}`

- `degree_distribution()` - Degree statistics (min, max, mean, median, std_dev)
  - Returns: `{:ok, %{min: _, max: _, mean: _, median: _, std_dev: _}}`

- `average_path_length()` - Mean shortest path length
  - Returns: `{:ok, avg_length}`

- `connectivity_metrics()` - Connectivity analysis
  - Returns: `{:ok, %{is_connected: _, component_count: _, largest_component_size: _}}`

- `summary()` - All metrics in one call
  - Returns: `{:ok, %{density: _, diameter: _, ...}}`

### CLI Commands

All analytics are also available via the CLI:
- `ANALYTICS PAGERANK` - Show top PageRank scores
- `ANALYTICS EIGENVECTOR` - Show top eigenvector centrality scores
- `ANALYTICS BETWEENNESS` - Show top betweenness scores
- `ANALYTICS CLOSENESS <node_id>` - Calculate closeness for node
- `ANALYTICS COMPONENTS` - List connected components
- `ANALYTICS LOUVAIN` - Show Louvain communities
- `ANALYTICS KCORE` - Display k-core decomposition
- `ANALYTICS TRIANGLES` - Show triangle counts
- `ANALYTICS CLUSTERING` - Global clustering coefficient
- `ANALYTICS DENSITY` - Graph density
- `ANALYTICS DIAMETER` - Graph diameter
- `ANALYTICS DEGREES` - Degree distribution
- `ANALYTICS SUMMARY` - Complete analytics summary
