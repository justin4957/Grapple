#!/usr/bin/env elixir

# Test script to verify ETS-based graph database functionality

# Make sure we can find the Grapple modules
Code.prepend_path("_build/dev/lib/grapple/ebin")

# Start dependencies first
Application.start(:logger)

# Start the application manually since we're in a script
{:ok, _} = Grapple.Application.start(nil, nil)

IO.puts("🚀 Testing Grapple ETS-based Graph Database")
IO.puts("=" |> String.duplicate(50))

# Test 1: Basic node and edge creation
IO.puts("\n📝 Test 1: Creating nodes and edges")

{:ok, node1} = Grapple.create_node(%{name: "Alice", role: "Engineer", level: 5})
{:ok, node2} = Grapple.create_node(%{name: "Bob", role: "Manager", level: 7})
{:ok, node3} = Grapple.create_node(%{name: "Carol", role: "Engineer", level: 6})
{:ok, node4} = Grapple.create_node(%{name: "David", role: "Director", level: 9})

IO.puts("✅ Created #{node1} nodes: Alice, Bob, Carol, David")

{:ok, edge1} = Grapple.create_edge(node1, node2, "reports_to", %{since: "2023"})
{:ok, edge2} = Grapple.create_edge(node3, node2, "reports_to", %{since: "2022"})
{:ok, edge3} = Grapple.create_edge(node2, node4, "reports_to", %{since: "2021"})
{:ok, edge4} = Grapple.create_edge(node1, node3, "collaborates", %{project: "GraphDB"})

IO.puts("✅ Created #{edge1 + edge2 + edge3 + edge4} edges with relationships")

# Test 2: Basic lookups
IO.puts("\n🔍 Test 2: Basic node and edge lookups")

case Grapple.get_node(node1) do
  {:ok, node} -> 
    IO.puts("✅ Retrieved Alice: #{inspect(node.properties)}")
  error -> 
    IO.puts("❌ Failed to retrieve Alice: #{inspect(error)}")
end

# Test 3: Property-based searches (using indexes)
IO.puts("\n📊 Test 3: Indexed property searches")

case Grapple.find_nodes_by_property(:role, "Engineer") do
  {:ok, engineers} ->
    IO.puts("✅ Found #{length(engineers)} engineers:")
    Enum.each(engineers, fn node ->
      IO.puts("   - #{node.properties.name} (Level #{node.properties.level})")
    end)
  error ->
    IO.puts("❌ Failed to find engineers: #{inspect(error)}")
end

case Grapple.find_edges_by_label("reports_to") do
  {:ok, reporting_edges} ->
    IO.puts("✅ Found #{length(reporting_edges)} reporting relationships")
  error ->
    IO.puts("❌ Failed to find reporting edges: #{inspect(error)}")
end

# Test 4: Graph traversal
IO.puts("\n🌐 Test 4: Graph traversal")

case Grapple.traverse(node4, :in, 2) do
  {:ok, reachable_nodes} ->
    IO.puts("✅ Traversed from David (incoming, depth 2): #{length(reachable_nodes)} nodes")
    Enum.each(reachable_nodes, fn node ->
      IO.puts("   - #{node.properties.name} (#{node.properties.role})")
    end)
  error ->
    IO.puts("❌ Traversal failed: #{inspect(error)}")
end

# Test 5: Path finding
IO.puts("\n🛤️ Test 5: Path finding")

case Grapple.find_path(node1, node4, 5) do
  {:ok, path} ->
    IO.puts("✅ Found path from Alice to David: #{inspect(path)}")
  {:error, :path_not_found} ->
    IO.puts("⚠️ No path found from Alice to David")
  error ->
    IO.puts("❌ Path finding failed: #{inspect(error)}")
end

# Test 6: Performance and statistics
IO.puts("\n📈 Test 6: Performance statistics")

stats = Grapple.get_stats()
IO.puts("✅ Graph statistics:")
IO.puts("   - Total nodes: #{stats.total_nodes}")
IO.puts("   - Total edges: #{stats.total_edges}")
IO.puts("   - Memory usage:")
IO.puts("     - Nodes: #{stats.memory_usage.nodes} words")
IO.puts("     - Edges: #{stats.memory_usage.edges} words")
IO.puts("     - Indexes: #{stats.memory_usage.indexes} words")

total_memory = stats.memory_usage.nodes + stats.memory_usage.edges + stats.memory_usage.indexes
IO.puts("     - Total: #{total_memory} words (~#{trunc(total_memory * 8 / 1024)} KB)")

# Test 7: Bulk operations performance test
IO.puts("\n⚡ Test 7: Performance test with bulk operations")

start_time = System.monotonic_time(:millisecond)

# Create 100 nodes quickly
nodes = 
  Enum.map(1..100, fn i ->
    {:ok, node_id} = Grapple.create_node(%{
      name: "User#{i}",
      department: if(rem(i, 3) == 0, do: "Engineering", else: "Sales"),
      level: rem(i, 10) + 1
    })
    node_id
  end)

# Create random edges between them
edges = 
  Enum.map(1..200, fn _i ->
    from = Enum.random(nodes)
    to = Enum.random(nodes)
    if from != to do
      {:ok, edge_id} = Grapple.create_edge(from, to, "knows", %{})
      edge_id
    end
  end)
  |> Enum.reject(&is_nil/1)

bulk_time = System.monotonic_time(:millisecond) - start_time

IO.puts("✅ Created 100 nodes and ~#{length(edges)} edges in #{bulk_time}ms")

# Test bulk property search
search_start = System.monotonic_time(:millisecond)
{:ok, eng_nodes} = Grapple.find_nodes_by_property(:department, "Engineering")
search_time = System.monotonic_time(:millisecond) - search_start

IO.puts("✅ Found #{length(eng_nodes)} engineering nodes in #{search_time}ms")

# Test bulk traversal
traversal_start = System.monotonic_time(:millisecond)
random_node = Enum.random(nodes)
{:ok, connected} = Grapple.traverse(random_node, :out, 3)
traversal_time = System.monotonic_time(:millisecond) - traversal_start

IO.puts("✅ Traversed from node #{random_node} (depth 3): #{length(connected)} nodes in #{traversal_time}ms")

# Final statistics
final_stats = Grapple.get_stats()
IO.puts("\n📊 Final statistics:")
IO.puts("   - Total nodes: #{final_stats.total_nodes}")
IO.puts("   - Total edges: #{final_stats.total_edges}")

final_memory = final_stats.memory_usage.nodes + final_stats.memory_usage.edges + final_stats.memory_usage.indexes
IO.puts("   - Total memory: #{final_memory} words (~#{trunc(final_memory * 8 / 1024)} KB)")

# Performance summary
IO.puts("\n🎯 Performance Summary:")
IO.puts("   - Node/Edge creation: ~#{trunc(300 / bulk_time * 1000)} ops/sec")
IO.puts("   - Property search: ~#{trunc(1000 / search_time)} ms response time")
IO.puts("   - Graph traversal: ~#{trunc(1000 / traversal_time)} ms response time")

IO.puts("\n🎉 All ETS functionality tests completed!")
IO.puts("=" |> String.duplicate(50))

IO.puts("\n💡 Try the interactive CLI:")
IO.puts("   mix compile && iex -S mix")
IO.puts("   Grapple.start_shell()")
IO.puts("   # Then use commands like:")
IO.puts("   # FIND NODES role Engineer")
IO.puts("   # FIND EDGES knows")
IO.puts("   # VISUALIZE 1 2")
IO.puts("   # SHOW GRAPH")