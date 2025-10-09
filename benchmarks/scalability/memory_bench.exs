# Benchmark for memory usage patterns
#
# Run with: mix run benchmarks/scalability/memory_bench.exs
#
# Analyzes memory consumption at different scales

IO.puts("Running memory usage benchmarks...\n")

Benchee.run(
  %{
    # === Per-Node Memory Overhead ===
    "memory: single node (minimal)" => fn ->
      {:ok, _id} = Grapple.create_node(%{})
    end,
    "memory: single node (5 properties)" => fn ->
      {:ok, _id} = Grapple.create_node(%{
        a: 1, b: 2, c: 3, d: 4, e: 5
      })
    end,
    "memory: single node (20 properties)" => fn ->
      props = for i <- 1..20, into: %{} do
        {String.to_atom("prop_#{i}"), i}
      end
      {:ok, _id} = Grapple.create_node(props)
    end,

    # === Per-Edge Memory Overhead ===
    "memory: single edge (no props)" => fn ->
      {:ok, n1} = Grapple.create_node(%{type: "temp"})
      {:ok, n2} = Grapple.create_node(%{type: "temp"})
      {:ok, _} = Grapple.create_edge(n1, n2, "test")
    end,
    "memory: single edge (5 properties)" => fn ->
      {:ok, n1} = Grapple.create_node(%{type: "temp"})
      {:ok, n2} = Grapple.create_node(%{type: "temp"})
      {:ok, _} = Grapple.create_edge(n1, n2, "test", %{
        a: 1, b: 2, c: 3, d: 4, e: 5
      })
    end,

    # === Batch Memory Patterns ===
    "memory: batch 100 nodes" => fn ->
      for i <- 1..100 do
        Grapple.create_node(%{batch: true, index: i})
      end
    end,
    "memory: batch 1000 nodes" => fn ->
      for i <- 1..1000 do
        Grapple.create_node(%{batch: true, index: i})
      end
    end,

    # === Index Memory Overhead ===
    "memory: 100 nodes with indexed property" => fn ->
      for i <- 1..100 do
        Grapple.create_node(%{
          indexed_field: "common_value",
          unique_id: i
        })
      end
    end,
    "memory: 100 nodes with unique properties" => fn ->
      for i <- 1..100 do
        Grapple.create_node(%{
          unique_field: "unique_#{i}",
          id: i
        })
      end
    end
  },
  time: 2,
  memory_time: 2,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/memory.html"}
  ],
  print: [
    fast_warning: false
  ]
)

# Get current stats for context
stats = Grapple.get_stats()

IO.puts("\n✅ Memory benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/memory.html")
IO.puts("\n📈 Current Database Stats:")
IO.puts("   Total Nodes: #{stats.total_nodes}")
IO.puts("   Total Edges: #{stats.total_edges}")

if Map.has_key?(stats, :memory_usage) do
  memory = stats.memory_usage
  total_kb = (memory.nodes + memory.edges + memory.indexes) * :erlang.system_info(:wordsize) / 1024
  IO.puts("   Total Memory: #{Float.round(total_kb, 2)} KB")
end

IO.puts("\n💡 Key Insight: Monitor per-node and per-edge overhead to plan capacity.")
