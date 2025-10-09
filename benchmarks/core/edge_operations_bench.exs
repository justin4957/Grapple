# Benchmark for core edge operations
#
# Run with: mix run benchmarks/core/edge_operations_bench.exs
#
# This benchmarks edge creation, retrieval, and label-based queries.

IO.puts("Setting up test data...")

# Create nodes for edge operations
{:ok, node1} = Grapple.create_node(%{name: "Alice", type: "user"})
{:ok, node2} = Grapple.create_node(%{name: "Bob", type: "user"})
{:ok, node3} = Grapple.create_node(%{name: "Charlie", type: "user"})
{:ok, node4} = Grapple.create_node(%{name: "Diana", type: "user"})

# Create a graph with various edge types for queries
nodes = for i <- 1..100 do
  {:ok, id} = Grapple.create_node(%{index: i, type: "benchmark_node"})
  id
end

# Create "follows" edges
for i <- 0..49 do
  {:ok, _} = Grapple.create_edge(
    Enum.at(nodes, i),
    Enum.at(nodes, i + 1),
    "follows",
    %{since: "2024"}
  )
end

# Create "friends_with" edges
for i <- 0..24 do
  {:ok, _} = Grapple.create_edge(
    Enum.at(nodes, i * 2),
    Enum.at(nodes, i * 2 + 1),
    "friends_with",
    %{strength: "strong"}
  )
end

# Create "collaborates_with" edges
for i <- 0..9 do
  {:ok, _} = Grapple.create_edge(
    Enum.at(nodes, i),
    Enum.at(nodes, i + 10),
    "collaborates_with",
    %{project: "test"}
  )
end

IO.puts("Running benchmarks...\n")

Benchee.run(
  %{
    # === Edge Creation ===
    "create_edge (no properties)" => fn ->
      {:ok, _id} = Grapple.create_edge(node1, node2, "knows")
    end,
    "create_edge (with properties)" => fn ->
      {:ok, _id} = Grapple.create_edge(node1, node3, "knows", %{
        since: "2024",
        strength: "strong",
        context: "work"
      })
    end,

    # === Batch Edge Creation ===
    "create_edge (batch 100)" => fn ->
      for i <- 0..99 do
        from_idx = rem(i, length(nodes))
        to_idx = rem(i + 1, length(nodes))
        Grapple.create_edge(
          Enum.at(nodes, from_idx),
          Enum.at(nodes, to_idx),
          "batch_edge",
          %{batch: "test", index: i}
        )
      end
    end,
    "create_edge (batch 1000)" => fn ->
      for i <- 0..999 do
        from_idx = rem(i, length(nodes))
        to_idx = rem(i + 2, length(nodes))
        Grapple.create_edge(
          Enum.at(nodes, from_idx),
          Enum.at(nodes, to_idx),
          "large_batch",
          %{index: i}
        )
      end
    end,

    # === Edge Queries by Label ===
    "find_edges_by_label (follows, ~50 results)" => fn ->
      {:ok, _edges} = Grapple.find_edges_by_label("follows")
    end,
    "find_edges_by_label (friends_with, ~25 results)" => fn ->
      {:ok, _edges} = Grapple.find_edges_by_label("friends_with")
    end,
    "find_edges_by_label (collaborates_with, ~10 results)" => fn ->
      {:ok, _edges} = Grapple.find_edges_by_label("collaborates_with")
    end,
    "find_edges_by_label (rare label, 0 results)" => fn ->
      {:ok, _edges} = Grapple.find_edges_by_label("nonexistent")
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/edge_operations.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Edge operations benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/edge_operations.html")
