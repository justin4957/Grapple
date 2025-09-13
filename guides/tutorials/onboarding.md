# Onboarding Tutorial

Welcome to Grapple! This tutorial will walk you through the core concepts and get you productive quickly.

## What is Grapple?

Grapple is a high-performance graph database built on Elixir/Erlang, designed for:

- **High Performance**: 300K+ operations/sec using ETS storage
- **Distributed Architecture**: Self-healing clusters with Mnesia coordination
- **Developer Friendly**: Rich CLI with autocomplete and visualization
- **Flexible Queries**: Powerful traversal and pathfinding capabilities

## Core Concepts

### Nodes
Nodes represent entities in your graph with arbitrary properties:

```elixir
{:ok, person} = Grapple.create_node(%{
  name: "Alice",
  age: 30,
  city: "San Francisco"
})
```

### Edges
Edges represent relationships between nodes:

```elixir
{:ok, edge} = Grapple.create_edge(alice_id, bob_id, "friends", %{
  since: "2020-01-15",
  strength: "strong"
})
```

### Queries
Find patterns and traverse your graph:

```elixir
# Find all friends
friends = Grapple.get_neighbors(alice_id)

# Find paths between nodes
path = Grapple.find_path(alice_id, charlie_id)

# Advanced queries
mutual_friends = Grapple.query("MATCH (a)-[:friends]-(b)-[:friends]-(c) WHERE a.id = #{alice_id} RETURN c")
```

## Hands-On Exercise

Let's build a simple social network:

```elixir
# Start Grapple
{:ok, _} = Grapple.start()

# Create people
{:ok, alice} = Grapple.create_node(%{name: "Alice", age: 30})
{:ok, bob} = Grapple.create_node(%{name: "Bob", age: 25})
{:ok, charlie} = Grapple.create_node(%{name: "Charlie", age: 35})

# Create friendships
{:ok, _} = Grapple.create_edge(alice, bob, "friends")
{:ok, _} = Grapple.create_edge(bob, charlie, "friends")

# Find Alice's network
alice_friends = Grapple.get_neighbors(alice)
alice_network = Grapple.traverse(alice, depth: 2)

# Visualize the graph
Grapple.visualize()
```

## CLI Exploration

The CLI provides an interactive way to explore your graph:

```bash
mix run -e "Grapple.CLI.Shell.start()"
```

Try these commands:
- `help` - See all available commands
- `create_node name:"Alice"` - Create a node
- `list_nodes` - Show all nodes
- `neighbors 1` - Find neighbors of node 1
- `visualize` - ASCII visualization
- `stats` - Performance statistics

## Performance Tips

1. **Batch Operations**: Use transactions for multiple operations
2. **Index Properties**: Frequently queried properties are auto-indexed
3. **Memory Management**: Monitor ETS table sizes
4. **Query Optimization**: Use specific traversal depths

## Next Steps

1. Complete the [Social Network Example](../examples/social-network.md)
2. Read the [Performance Guide](../advanced/performance.md)
3. Explore [Distributed Features](../../README_DISTRIBUTED.md)
4. Join our community discussions

## Getting Help

- Use `help` in the CLI for command reference
- Check the [Complete User Guide](../../GUIDE.md)
- Review performance benchmarks and optimization tips