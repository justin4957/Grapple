# Grapple Quickstart Guide 🚀

Welcome to Grapple! This guide will get you up and running in just a few minutes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Running the Demo](#running-the-demo)
- [Exploring the Graph](#exploring-the-graph)
- [Interactive CLI](#interactive-cli)
- [Web Dashboard](#web-dashboard)
- [Example Scenarios](#example-scenarios)
- [Next Steps](#next-steps)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Elixir 1.18+** - [Install Elixir](https://elixir-lang.org/install.html)
- **Erlang/OTP 27+** - Usually comes with Elixir
- **Node.js 18+** (for Phoenix web UI) - [Install Node.js](https://nodejs.org/)
- **Git** - For cloning the repository

Verify your installation:

```bash
elixir --version
# Should show: Elixir 1.18.x (compiled with Erlang/OTP 27)

node --version
# Should show: v18.x.x or higher
```

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/justin4957/Grapple.git
cd Grapple
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies for Phoenix web UI
cd assets && npm install && cd ..
```

### 3. Compile the Project

```bash
mix compile
```

## Running the Demo

Grapple includes a comprehensive quickstart demo that populates the database with sample data. This is the fastest way to see Grapple in action!

### Run the Demo Script

```bash
mix run demo/quickstart.exs
```

This will:
- Create **10 users** with different roles and departments
- Add **29 interest/technology nodes**
- Create **24 relationships** (reports_to, friends_with, mentors, collaborates_with)
- Connect users to their interests
- Run example queries to demonstrate features
- Display helpful statistics and next steps

### What You'll See

The demo will output:

```
╔═══════════════════════════════════════════════════╗
║  Grapple Quickstart Demo - Social Network        ║
╚═══════════════════════════════════════════════════╝

📊 Starting with fresh database...

👥 Creating users...
  ✓ Created Alice (ID: 1)
  ✓ Created Bob (ID: 2)
  ...

🤝 Creating relationships...
  ✓ Created 24 relationships

═════════════ Database Statistics ═════════════
  📊 Total Nodes: 39
  🔗 Total Edges: 54

═════════════ Example Queries ═════════════
...
```

## Exploring the Graph

After running the demo, the database is populated with data. You can now explore it!

### Quick Exploration in IEx

```bash
# Start an interactive Elixir shell
iex -S mix
```

```elixir
# Get database statistics
stats = Grapple.get_stats()
# => %{total_nodes: 39, total_edges: 54, memory_usage: ...}

# Find all engineers
{:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
length(engineers)
# => 4

# Find all friendships
{:ok, friendships} = Grapple.find_edges_by_label("friends_with")
length(friendships)
# => 6

# Get a specific node
{:ok, alice_node} = Grapple.find_nodes_by_property(:name, "Alice")
alice_id = hd(alice_node).id
{:ok, node} = Grapple.get_node(alice_id)
# => %{id: 1, properties: %{name: "Alice", role: "Engineer", ...}}

# Traverse from Alice (find connections)
{:ok, neighbors} = Grapple.traverse(alice_id, :out, 1)
# => [list of connected nodes]

# Find shortest path
{:ok, bob_node} = Grapple.find_nodes_by_property(:name, "Bob")
bob_id = hd(bob_node).id
{:ok, path} = Grapple.find_path(alice_id, bob_id)
# => [1, 2] (Alice → Bob)
```

## Interactive CLI

Grapple includes a powerful interactive CLI with syntax highlighting and autocomplete.

### Start the CLI

```elixir
# In iex -S mix
Grapple.start_shell()
```

### CLI Commands

```
grapple> help

Available Commands:
  CREATE NODE {properties}         - Create a new node
  CREATE EDGE (from)-[label]->(to) - Create an edge
  MATCH (pattern)                  - Pattern matching
  FIND NODES property: value       - Find nodes by property
  FIND EDGES label                 - Find edges by label
  TRAVERSE node_id direction depth - Traverse graph
  PATH from_id to_id               - Find shortest path
  ANALYTICS summary                - Graph analytics
  ANALYTICS pagerank               - PageRank scores
  VISUALIZE node_id ...            - ASCII visualization
  STATS                            - Database statistics
  CLUSTER STATUS                   - Cluster information
  HELP                             - Show this help
  QUIT                             - Exit shell
```

### Example CLI Session

```
grapple> CREATE NODE {name: "Sarah", role: "Engineer", department: "ML"}
✅ Created node with ID: 40

grapple> FIND NODES role: Engineer
Found 5 nodes:
  • Node 1: Alice (Backend)
  • Node 4: Diana (Frontend)
  • Node 7: Grace (Backend)
  • Node 9: Ivy (ML)
  • Node 40: Sarah (ML)

grapple> TRAVERSE 1 out 2
Found 15 connected nodes within depth 2

grapple> PATH 1 2
Shortest path (length 2): 1 → 2

grapple> ANALYTICS summary
Graph Summary:
  Nodes: 40
  Edges: 54
  Density: 0.069
  Connected Components: 1
  Average Degree: 2.7

grapple> STATS
Database Statistics:
  Total Nodes: 40
  Total Edges: 54
  Memory Usage:
    Nodes: 45.2 KB
    Edges: 38.7 KB
    Indexes: 12.1 KB
```

## Web Dashboard

Grapple includes a Phoenix LiveView web dashboard for visual exploration.

### Start the Phoenix Server

```bash
mix phx.server
```

Then open your browser to:

```
http://localhost:4000
```

### Dashboard Features

- **📊 Dashboard** - Overview with key metrics and statistics
- **🕸️ Graph Visualization** - Interactive Cytoscape.js visualization
- **🔍 Query Interface** - Run queries and see results
- **📈 Analytics** - View graph metrics, centrality scores, and community detection
- **🖥️ Cluster Management** - Monitor distributed cluster (if enabled)

### Dashboard Tips

1. **Zoom and Pan** - Use mouse wheel to zoom, drag to pan the graph
2. **Node Selection** - Click nodes to see details
3. **Query Builder** - Use the query interface to filter and search
4. **Real-time Updates** - LiveView automatically updates statistics

## Example Scenarios

### Scenario 1: Social Network Analysis

```elixir
# Find all friendship connections
{:ok, friendships} = Grapple.find_edges_by_label("friends_with")

# Analyze friendship strength
strong_friendships = Enum.filter(friendships, fn edge ->
  edge.properties[:strength] == "strong"
end)

# Find the most connected person (manual degree calculation)
friend_counts = Enum.reduce(friendships, %{}, fn edge, acc ->
  acc
  |> Map.update(edge.from, 1, &(&1 + 1))
  |> Map.update(edge.to, 1, &(&1 + 1))
end)

# Get the top connector
{top_connector_id, connection_count} = Enum.max_by(friend_counts, fn {_id, count} -> count end)
{:ok, top_connector} = Grapple.get_node(top_connector_id)
IO.puts("Most connected: #{top_connector.properties.name} with #{connection_count} connections")
```

### Scenario 2: Organizational Hierarchy

```elixir
# Find all managers
{:ok, all_nodes} = Grapple.find_nodes_by_property(:role, "Manager")
managers = Enum.filter(all_nodes, &String.contains?(&1.properties.role, "Manager"))

# Find who reports to Bob
{:ok, bob_node} = Grapple.find_nodes_by_property(:name, "Bob")
bob_id = hd(bob_node).id
{:ok, direct_reports} = Grapple.traverse(bob_id, :in, 1)

# Filter for actual employees (exclude interests)
employees = Enum.filter(direct_reports, fn node ->
  Map.has_key?(node.properties, :name) && Map.has_key?(node.properties, :role)
end)

IO.puts("Bob has #{length(employees)} direct reports")
```

### Scenario 3: Knowledge Graph - Find Experts

```elixir
# Find people interested in "Elixir"
{:ok, elixir_interests} = Grapple.find_nodes_by_property(:name, "Elixir")

if length(elixir_interests) > 0 do
  elixir_id = hd(elixir_interests).id

  # Traverse backwards to find who is interested
  {:ok, interested_people} = Grapple.traverse(elixir_id, :in, 1)

  # Get expert-level users
  experts = Enum.filter(interested_people, fn person ->
    Map.get(person.properties, :role) in ["Engineer", "Data Scientist"]
  end)

  IO.puts("Found #{length(experts)} Elixir experts")
end
```

### Scenario 4: Path Finding

```elixir
# Find connection between two people
{:ok, alice_nodes} = Grapple.find_nodes_by_property(:name, "Alice")
{:ok, henry_nodes} = Grapple.find_nodes_by_property(:name, "Henry")

alice_id = hd(alice_nodes).id
henry_id = hd(henry_nodes).id

{:ok, path} = Grapple.find_path(alice_id, henry_id)

# Get names for the path
path_names = Enum.map(path, fn node_id ->
  {:ok, node} = Grapple.get_node(node_id)
  Map.get(node.properties, :name, "Unknown")
end)

IO.puts("Connection path: #{Enum.join(path_names, " → ")}")
```

### Scenario 5: Analytics

```elixir
# Graph summary
{:ok, summary} = Grapple.Analytics.summary()
IO.inspect(summary, label: "Graph Summary")

# PageRank - find influential nodes
{:ok, pageranks} = Grapple.Analytics.pagerank()
top_influential =
  pageranks
  |> Enum.sort_by(fn {_id, score} -> -score end)
  |> Enum.take(5)

IO.puts("\nTop 5 Influential Nodes:")
Enum.each(top_influential, fn {node_id, score} ->
  {:ok, node} = Grapple.get_node(node_id)
  name = Map.get(node.properties, :name, "Node #{node_id}")
  IO.puts("  #{name}: #{Float.round(score, 4)}")
end)

# Connected components
{:ok, components} = Grapple.Analytics.connected_components()
IO.puts("\nFound #{map_size(components)} connected components")

# Clustering coefficient
{:ok, clustering} = Grapple.Analytics.clustering_coefficient()
avg_clustering = Enum.sum(Map.values(clustering)) / map_size(clustering)
IO.puts("\nAverage clustering coefficient: #{Float.round(avg_clustering, 4)}")
```

## Next Steps

### Learn More

- **[Complete User Guide](GUIDE.md)** - Comprehensive documentation
- **[Architecture Overview](guides/advanced/architecture.md)** - How Grapple works
- **[API Documentation](https://hexdocs.pm/grapple)** - Full API reference
- **[Performance Guide](guides/advanced/performance.md)** - Optimization tips

### Build Your Own Graph

```elixir
# Start fresh in IEx
iex -S mix

# Create your domain model
{:ok, user1} = Grapple.create_node(%{type: "User", email: "user@example.com"})
{:ok, product1} = Grapple.create_node(%{type: "Product", name: "Widget", price: 29.99})
{:ok, _edge} = Grapple.create_edge(user1, product1, "purchased", %{date: "2024-10-09"})

# Query your data
{:ok, users} = Grapple.find_nodes_by_property(:type, "User")
{:ok, purchases} = Grapple.find_edges_by_label("purchased")
```

### Enable Distributed Mode

For production deployments with multiple nodes:

```elixir
# config/config.exs
config :grapple,
  distributed: true,
  cluster_name: "grapple_cluster"

# Start multiple nodes
# Terminal 1:
iex --name node1@127.0.0.1 --cookie secret -S mix

# Terminal 2:
iex --name node2@127.0.0.1 --cookie secret -S mix

# In node2:
Grapple.join_cluster(:"node1@127.0.0.1")

# Check cluster status
Grapple.cluster_info()
```

### Explore Advanced Features

- **Lifecycle Management** - Classify data as ephemeral, computational, or persistent
- **Replication Strategies** - Use adaptive replication for critical data
- **Custom Algorithms** - Implement your own graph algorithms
- **Query Language** - Use Cypher-like pattern matching
- **Performance Monitoring** - Profile and optimize queries

### Join the Community

- **GitHub Issues** - [Report bugs or request features](https://github.com/justin4957/Grapple/issues)
- **GitHub Discussions** - [Ask questions and share ideas](https://github.com/justin4957/Grapple/discussions)
- **Contributing** - [Read the contribution guide](CONTRIBUTING.md)

## Common Commands Reference

### Node Operations

```elixir
# Create node
{:ok, id} = Grapple.create_node(%{name: "Alice", role: "Engineer"})

# Get node
{:ok, node} = Grapple.get_node(id)

# Find nodes by property
{:ok, nodes} = Grapple.find_nodes_by_property(:role, "Engineer")
```

### Edge Operations

```elixir
# Create edge
{:ok, edge_id} = Grapple.create_edge(from_id, to_id, "knows", %{since: "2024"})

# Find edges by label
{:ok, edges} = Grapple.find_edges_by_label("knows")
```

### Graph Traversal

```elixir
# Traverse (BFS)
{:ok, neighbors} = Grapple.traverse(start_id, :out, 2)

# Find shortest path
{:ok, path} = Grapple.find_path(from_id, to_id)

# Find path with max depth
{:ok, path} = Grapple.find_path(from_id, to_id, 5)
```

### Analytics

```elixir
# Graph summary
{:ok, summary} = Grapple.Analytics.summary()

# PageRank
{:ok, scores} = Grapple.Analytics.pagerank()

# Connected components
{:ok, components} = Grapple.Analytics.connected_components()

# Betweenness centrality
{:ok, betweenness} = Grapple.Analytics.betweenness_centrality()

# Clustering coefficient
{:ok, clustering} = Grapple.Analytics.clustering_coefficient()
```

### System Operations

```elixir
# Get statistics
stats = Grapple.get_stats()

# Cluster info
info = Grapple.cluster_info()

# Join cluster
{:ok, :connected} = Grapple.join_cluster(:"node2@hostname")
```

## Troubleshooting

### Demo doesn't run

**Problem:** `mix run demo/quickstart.exs` fails

**Solution:**
```bash
# Make sure dependencies are installed
mix deps.get
mix compile

# Try running in IEx for better error messages
iex -S mix
Code.require_file("demo/quickstart.exs")
```

### Phoenix server won't start

**Problem:** `mix phx.server` fails with asset errors

**Solution:**
```bash
# Install Node.js dependencies
cd assets
npm install
cd ..

# Try again
mix phx.server
```

### Can't find nodes/edges

**Problem:** Queries return empty results after running demo

**Solution:**
The demo creates fresh data each run. Make sure you:
1. Run `mix run demo/quickstart.exs` first
2. Then immediately query in the same session
3. Or query using the Phoenix web interface

### Need more help?

Check out:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [FAQ.md](FAQ.md) - Frequently asked questions
- [GitHub Issues](https://github.com/justin4957/Grapple/issues) - Search existing issues

---

**Happy Graphing! 🎉**

Need help? [Open an issue](https://github.com/justin4957/Grapple/issues) or check out the [documentation](GUIDE.md).
