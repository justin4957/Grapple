# Benchmark for graph traversal operations
#
# Run with: mix run benchmarks/core/traversal_bench.exs
#
# This benchmarks traversal and path finding operations at various depths.

Code.require_file("../support/graph_generator.ex", __DIR__)

IO.puts("Generating test graphs...")

# Create a linear chain for worst-case path finding
IO.puts("  - Linear chain (100 nodes)...")
{chain_nodes, _chain_edges} = Grapple.Benchmarks.GraphGenerator.linear_chain(100)
chain_start = hd(chain_nodes)
chain_end = List.last(chain_nodes)

# Create a binary tree for balanced traversal
IO.puts("  - Binary tree (depth 6, 127 nodes)...")
{tree_nodes, _tree_edges} = Grapple.Benchmarks.GraphGenerator.binary_tree(6)
tree_root = hd(tree_nodes)

# Create a dense graph for complex traversal
IO.puts("  - Dense graph (50 nodes, ~600 edges)...")
{dense_nodes, _dense_edges} = Grapple.Benchmarks.GraphGenerator.dense_graph(50, 0.5)
dense_start = hd(dense_nodes)

# Create a social network graph
IO.puts("  - Social network (100 nodes, power-law distribution)...")
{social_nodes, _social_edges} = Grapple.Benchmarks.GraphGenerator.social_network(100, 8)
social_start = hd(social_nodes)
social_mid = Enum.at(social_nodes, 50)

IO.puts("Running benchmarks...\n")

Benchee.run(
  %{
    # === Traversal at Different Depths ===
    "traverse (depth 1, out)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(chain_start, :out, 1)
    end,
    "traverse (depth 2, out)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(tree_root, :out, 2)
    end,
    "traverse (depth 3, out)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(tree_root, :out, 3)
    end,
    "traverse (depth 5, out)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(tree_root, :out, 5)
    end,

    # === Traversal Directions ===
    "traverse (depth 2, in)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(chain_end, :in, 2)
    end,
    "traverse (depth 2, both)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(Enum.at(chain_nodes, 50), :both, 2)
    end,

    # === Path Finding ===
    "find_path (short, 2 hops)" => fn ->
      {:ok, _path} = Grapple.find_path(chain_start, Enum.at(chain_nodes, 2))
    end,
    "find_path (medium, 10 hops)" => fn ->
      {:ok, _path} = Grapple.find_path(chain_start, Enum.at(chain_nodes, 10))
    end,
    "find_path (long, 50 hops)" => fn ->
      {:ok, _path} = Grapple.find_path(chain_start, Enum.at(chain_nodes, 50))
    end,
    "find_path (very long, 99 hops)" => fn ->
      {:ok, _path} = Grapple.find_path(chain_start, chain_end)
    end,

    # === Different Graph Structures ===
    "traverse (dense graph, depth 2)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(dense_start, :out, 2)
    end,
    "traverse (social network, depth 2)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(social_start, :out, 2)
    end,

    # === Path Finding in Different Structures ===
    "find_path (dense graph)" => fn ->
      {:ok, _path} = Grapple.find_path(
        hd(dense_nodes),
        Enum.at(dense_nodes, 25)
      )
    end,
    "find_path (social network)" => fn ->
      {:ok, _path} = Grapple.find_path(social_start, social_mid)
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/traversal.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Traversal benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/traversal.html")
