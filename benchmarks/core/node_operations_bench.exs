# Benchmark for core node operations
#
# Run with: mix run benchmarks/core/node_operations_bench.exs
#
# This benchmarks the fundamental node operations that form
# the basis of all graph database interactions.

# Setup: Create some existing nodes for read/update operations
IO.puts("Setting up test data...")

{:ok, existing_node_id} = Grapple.create_node(%{name: "test", type: "benchmark"})

# Create nodes with various property counts for property query benchmarks
for i <- 1..1000 do
  Grapple.create_node(%{
    type: "user",
    index: i,
    active: rem(i, 2) == 0,
    score: :rand.uniform(100)
  })
end

for i <- 1..500 do
  Grapple.create_node(%{
    type: "product",
    index: i,
    category: Enum.random(["electronics", "books", "clothing"]),
    price: :rand.uniform(1000)
  })
end

IO.puts("Running benchmarks...\n")

Benchee.run(
  %{
    # === Node Creation ===
    "create_node (minimal)" => fn ->
      {:ok, _id} = Grapple.create_node(%{})
    end,
    "create_node (3 properties)" => fn ->
      {:ok, _id} = Grapple.create_node(%{
        name: "Alice",
        age: 28,
        role: "Engineer"
      })
    end,
    "create_node (10 properties)" => fn ->
      {:ok, _id} = Grapple.create_node(%{
        name: "Bob",
        age: 35,
        role: "Manager",
        department: "Engineering",
        level: "Senior",
        location: "Remote",
        skills: "Leadership",
        experience: 12,
        active: true,
        team_size: 8
      })
    end,

    # === Batch Node Creation ===
    "create_node (batch 100)" => fn ->
      for i <- 1..100 do
        Grapple.create_node(%{batch: "test", index: i})
      end
    end,
    "create_node (batch 1000)" => fn ->
      for i <- 1..1000 do
        Grapple.create_node(%{batch: "large", index: i})
      end
    end,

    # === Node Retrieval ===
    "get_node (by ID)" => fn ->
      {:ok, _node} = Grapple.get_node(existing_node_id)
    end,

    # === Property-Based Queries ===
    "find_nodes_by_property (type=user, 1K results)" => fn ->
      {:ok, _nodes} = Grapple.find_nodes_by_property(:type, "user")
    end,
    "find_nodes_by_property (type=product, 500 results)" => fn ->
      {:ok, _nodes} = Grapple.find_nodes_by_property(:type, "product")
    end,
    "find_nodes_by_property (rare property, 1 result)" => fn ->
      {:ok, _nodes} = Grapple.find_nodes_by_property(:name, "test")
    end,
    "find_nodes_by_property (active=true, ~500 results)" => fn ->
      {:ok, _nodes} = Grapple.find_nodes_by_property(:active, true)
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/node_operations.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Node operations benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/node_operations.html")
