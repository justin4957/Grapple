# Benchmark for concurrent operations
#
# Run with: mix run benchmarks/scalability/concurrency_bench.exs
#
# Tests how Grapple performs under concurrent load

IO.puts("Setting up test data for concurrency benchmarks...")

# Create a moderate-sized graph for concurrent testing
nodes = for i <- 1..1000 do
  {:ok, id} = Grapple.create_node(%{
    index: i,
    type: "concurrent_test",
    value: :rand.uniform(1000)
  })
  id
end

# Create edges
for i <- 0..499 do
  {:ok, _} = Grapple.create_edge(
    Enum.at(nodes, i),
    Enum.at(nodes, i + 1),
    "connects",
    %{weight: :rand.uniform(100)}
  )
end

IO.puts("Running concurrent load benchmarks...\n")

Benchee.run(
  %{
    # === Read-Heavy Workloads ===
    "concurrent reads (10 tasks)" => fn ->
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          node = Enum.random(nodes)
          {:ok, _} = Grapple.get_node(node)
        end)
      end
      Task.await_many(tasks)
    end,
    "concurrent reads (100 tasks)" => fn ->
      tasks = for _ <- 1..100 do
        Task.async(fn ->
          node = Enum.random(nodes)
          {:ok, _} = Grapple.get_node(node)
        end)
      end
      Task.await_many(tasks)
    end,
    "concurrent reads (1000 tasks)" => fn ->
      tasks = for _ <- 1..1000 do
        Task.async(fn ->
          node = Enum.random(nodes)
          {:ok, _} = Grapple.get_node(node)
        end)
      end
      Task.await_many(tasks)
    end,

    # === Write-Heavy Workloads ===
    "concurrent writes (10 tasks)" => fn ->
      tasks = for i <- 1..10 do
        Task.async(fn ->
          {:ok, _} = Grapple.create_node(%{concurrent: true, task: i})
        end)
      end
      Task.await_many(tasks)
    end,
    "concurrent writes (100 tasks)" => fn ->
      tasks = for i <- 1..100 do
        Task.async(fn ->
          {:ok, _} = Grapple.create_node(%{concurrent: true, task: i})
        end)
      end
      Task.await_many(tasks)
    end,

    # === Mixed Workloads (90/10 Read/Write) ===
    "mixed 90/10 (100 tasks)" => fn ->
      tasks = for i <- 1..100 do
        Task.async(fn ->
          if rem(i, 10) == 0 do
            # 10% writes
            {:ok, _} = Grapple.create_node(%{mixed: true, task: i})
          else
            # 90% reads
            node = Enum.random(nodes)
            {:ok, _} = Grapple.get_node(node)
          end
        end)
      end
      Task.await_many(tasks)
    end,

    # === Mixed Workloads (70/30 Read/Write) ===
    "mixed 70/30 (100 tasks)" => fn ->
      tasks = for i <- 1..100 do
        Task.async(fn ->
          if rem(i, 10) < 3 do
            # 30% writes
            {:ok, _} = Grapple.create_node(%{mixed: true, task: i})
          else
            # 70% reads
            node = Enum.random(nodes)
            {:ok, _} = Grapple.get_node(node)
          end
        end)
      end
      Task.await_many(tasks)
    end,

    # === Traversal Under Load ===
    "concurrent traversals (10 tasks)" => fn ->
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          node = Enum.random(nodes)
          {:ok, _} = Grapple.traverse(node, :out, 2)
        end)
      end
      Task.await_many(tasks)
    end,
    "concurrent traversals (50 tasks)" => fn ->
      tasks = for _ <- 1..50 do
        Task.async(fn ->
          node = Enum.random(nodes)
          {:ok, _} = Grapple.traverse(node, :out, 2)
        end)
      end
      Task.await_many(tasks)
    end
  },
  time: 3,
  memory_time: 1,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/concurrency.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Concurrent load benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/concurrency.html")
IO.puts("\n💡 Key Insight: ETS provides lock-free reads, expect excellent read concurrency.")
