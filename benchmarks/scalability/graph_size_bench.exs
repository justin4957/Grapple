# Benchmark for graph size scaling
#
# Run with: mix run benchmarks/scalability/graph_size_bench.exs
#
# Tests how performance scales with graph size from 100 to 100K nodes

Code.require_file("../support/graph_generator.ex", __DIR__)

IO.puts("Setting up graphs at different scales...\n")
IO.puts("⚠️  This benchmark may take several minutes to complete.\n")

# Test sizes: Tiny, Small, Medium, Large
graph_sizes = [
  {100, "tiny"},
  {1_000, "small"},
  {10_000, "medium"},
  {50_000, "large"}
]

# Generate graphs and capture IDs for testing
graphs = Enum.map(graph_sizes, fn {size, label} ->
  IO.puts("  Creating #{label} graph (#{size} nodes)...")
  {nodes, _edges} = Grapple.Benchmarks.GraphGenerator.social_network(size, 8)
  {label, nodes, size}
end)

IO.puts("\nRunning scalability benchmarks...\n")

# Create benchmark scenarios for each graph size
scenarios = Enum.reduce(graphs, %{}, fn {label, nodes, size}, acc ->
  first_node = hd(nodes)
  mid_node = Enum.at(nodes, div(length(nodes), 2))

  Map.merge(acc, %{
    "create_node (#{label}, #{size} existing)" => fn ->
      {:ok, _id} = Grapple.create_node(%{
        graph: label,
        created_at: System.system_time(:millisecond)
      })
    end,
    "get_node (#{label}, #{size} nodes)" => fn ->
      {:ok, _node} = Grapple.get_node(first_node)
    end,
    "find_nodes_by_property (#{label}, #{size} nodes)" => fn ->
      {:ok, _nodes} = Grapple.find_nodes_by_property(:type, "user")
    end,
    "traverse depth 2 (#{label}, #{size} nodes)" => fn ->
      {:ok, _neighbors} = Grapple.traverse(first_node, :out, 2)
    end,
    "find_path (#{label}, #{size} nodes)" => fn ->
      {:ok, _path} = Grapple.find_path(first_node, mid_node, 10)
    end
  })
end)

Benchee.run(
  scenarios,
  time: 3,
  memory_time: 1,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/graph_size_scaling.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Graph size scaling benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/graph_size_scaling.html")
IO.puts("\n💡 Key Insight: Compare performance across graph sizes to identify scaling characteristics.")
