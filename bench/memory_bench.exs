defmodule Grapple.Benchmarks.Memory do
  @moduledoc """
  Memory profiling and analysis benchmarks.

  Run with: mix run bench/memory_bench.exs
  """

  # Start the application
  Application.ensure_all_started(:grapple)

  # Ensure ETS store is started
  case Grapple.Storage.EtsGraphStore.start_link() do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
  end

  clear_graph = fn ->
    try do
      :ets.delete_all_objects(:grapple_nodes)
      :ets.delete_all_objects(:grapple_edges)
      :ets.delete_all_objects(:grapple_node_edges_out)
      :ets.delete_all_objects(:grapple_node_edges_in)
      :ets.delete_all_objects(:grapple_property_index)
      :ets.delete_all_objects(:grapple_label_index)
    catch
      _ -> :ok
    end
  end

  IO.puts("Memory Usage Analysis\n")
  IO.puts("=" |> String.duplicate(80))

  # Test 1: Memory usage for nodes
  clear_graph.()
  initial_stats = Grapple.get_stats()

  IO.puts("\nInitial memory usage (empty graph):")
  IO.puts("  Nodes table: #{initial_stats.memory_usage.nodes} words")
  IO.puts("  Edges table: #{initial_stats.memory_usage.edges} words")
  IO.puts("  Indexes: #{initial_stats.memory_usage.indexes} words")

  total_initial =
    initial_stats.memory_usage.nodes +
      initial_stats.memory_usage.edges +
      initial_stats.memory_usage.indexes

  IO.puts("  Total: #{total_initial} words (~#{div(total_initial * 8, 1024)} KB)")

  # Create 1000 nodes
  IO.puts("\nCreating 1000 nodes...")

  1..1000
  |> Enum.each(fn i ->
    Grapple.create_node(%{
      id: i,
      name: "Node#{i}",
      category: "category_#{rem(i, 10)}",
      value: i * 100
    })
  end)

  stats_1k = Grapple.get_stats()

  IO.puts("\nMemory usage after 1000 nodes:")
  IO.puts("  Nodes table: #{stats_1k.memory_usage.nodes} words")
  IO.puts("  Edges table: #{stats_1k.memory_usage.edges} words")
  IO.puts("  Indexes: #{stats_1k.memory_usage.indexes} words")

  total_1k =
    stats_1k.memory_usage.nodes +
      stats_1k.memory_usage.edges +
      stats_1k.memory_usage.indexes

  IO.puts("  Total: #{total_1k} words (~#{div(total_1k * 8, 1024)} KB)")

  per_node_1k = div(total_1k - total_initial, 1000)
  IO.puts("  Memory per node: ~#{per_node_1k} words (~#{div(per_node_1k * 8, 1024)} KB)")

  # Create 10000 more nodes (11000 total)
  IO.puts("\nCreating 10000 additional nodes (11000 total)...")

  1001..11_000
  |> Enum.each(fn i ->
    Grapple.create_node(%{
      id: i,
      name: "Node#{i}",
      category: "category_#{rem(i, 10)}",
      value: i * 100
    })
  end)

  stats_11k = Grapple.get_stats()

  IO.puts("\nMemory usage after 11000 nodes:")
  IO.puts("  Nodes table: #{stats_11k.memory_usage.nodes} words")
  IO.puts("  Edges table: #{stats_11k.memory_usage.edges} words")
  IO.puts("  Indexes: #{stats_11k.memory_usage.indexes} words")

  total_11k =
    stats_11k.memory_usage.nodes +
      stats_11k.memory_usage.edges +
      stats_11k.memory_usage.indexes

  IO.puts("  Total: #{total_11k} words (~#{div(total_11k * 8, 1024)} KB)")

  per_node_11k = div(total_11k - total_initial, 11_000)
  IO.puts("  Memory per node: ~#{per_node_11k} words (~#{div(per_node_11k * 8, 1024)} KB)")

  # Test edges memory usage
  IO.puts("\nCreating 10000 edges...")

  node_ids = 1..11_000 |> Enum.to_list()

  1..10_000
  |> Enum.each(fn i ->
    from = Enum.at(node_ids, rem(i, 11_000))
    to = Enum.at(node_ids, rem(i + 1, 11_000))
    Grapple.create_edge(from, to, "test_edge", %{weight: rem(i, 100)})
  end)

  stats_with_edges = Grapple.get_stats()

  IO.puts("\nMemory usage after adding 10000 edges:")
  IO.puts("  Nodes table: #{stats_with_edges.memory_usage.nodes} words")
  IO.puts("  Edges table: #{stats_with_edges.memory_usage.edges} words")
  IO.puts("  Indexes: #{stats_with_edges.memory_usage.indexes} words")

  total_with_edges =
    stats_with_edges.memory_usage.nodes +
      stats_with_edges.memory_usage.edges +
      stats_with_edges.memory_usage.indexes

  IO.puts("  Total: #{total_with_edges} words (~#{div(total_with_edges * 8, 1024)} KB)")

  edge_memory = stats_with_edges.memory_usage.edges - stats_11k.memory_usage.edges
  per_edge = div(edge_memory, 10_000)

  IO.puts("  Memory per edge: ~#{per_edge} words (~#{div(per_edge * 8, 1024)} KB)")

  IO.puts("\n" <> ("=" |> String.duplicate(80)))
  IO.puts("\nSummary:")
  IO.puts("  Average memory per node: ~#{per_node_11k} words")
  IO.puts("  Average memory per edge: ~#{per_edge} words")
  IO.puts("  Total graph size: 11000 nodes, 10000 edges")
  IO.puts("  Total memory: ~#{div(total_with_edges * 8, 1024)} KB")

  estimated_100k = div((per_node_11k * 100_000 + per_edge * 100_000) * 8, 1024)
  estimated_1m = div((per_node_11k * 1_000_000 + per_edge * 1_000_000) * 8, 1024 * 1024)

  IO.puts("\nProjections:")
  IO.puts("  100K nodes + 100K edges: ~#{estimated_100k} KB (~#{div(estimated_100k, 1024)} MB)")
  IO.puts("  1M nodes + 1M edges: ~#{estimated_1m} MB (~#{Float.round(estimated_1m / 1024, 2)} GB)")

  IO.puts("\nMemory profiling complete!")
end
