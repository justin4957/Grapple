defmodule Grapple.Benchmarks.Scalability do
  @moduledoc """
  Scalability benchmarks to test performance at different graph sizes.

  Run with: mix run bench/scalability_bench.exs
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

  test_batch_creation = fn size ->
    fn ->
      clear_graph.()

      1..size
      |> Enum.each(fn i ->
        Grapple.create_node(%{
          id: i,
          name: "Node#{i}",
          category: "category_#{rem(i, 10)}"
        })
      end)
    end
  end

  test_property_lookup_scaling = fn size ->
    clear_graph.()

    # Pre-create nodes
    1..size
    |> Enum.each(fn i ->
      Grapple.create_node(%{
        category: "test",
        value: rem(i, 100)
      })
    end)

    fn ->
      Grapple.find_nodes_by_property(:category, "test")
    end
  end

  IO.puts("Running scalability benchmarks...")
  IO.puts("This will test performance at different graph sizes\n")

  # Test batch node creation at different scales
  Benchee.run(
    %{
      "batch_create_100_nodes" => test_batch_creation.(100),
      "batch_create_1000_nodes" => test_batch_creation.(1000),
      "batch_create_10000_nodes" => test_batch_creation.(10_000),
      "batch_create_50000_nodes" => test_batch_creation.(50_000)
    },
    time: 5,
    warmup: 1,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/results/scalability_creation.html"}
    ]
  )

  IO.puts("\n--- Property Lookup Scaling ---\n")

  # Test property lookup performance at different scales
  Benchee.run(
    %{
      "property_lookup_100_nodes" => test_property_lookup_scaling.(100),
      "property_lookup_1000_nodes" => test_property_lookup_scaling.(1000),
      "property_lookup_10000_nodes" => test_property_lookup_scaling.(10_000),
      "property_lookup_50000_nodes" => test_property_lookup_scaling.(50_000)
    },
    time: 5,
    warmup: 1,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/results/scalability_lookup.html"}
    ]
  )

  IO.puts("\n--- Edge Creation Scaling ---\n")

  # Test edge creation at different scales
  test_edge_creation = fn node_count, edge_count ->
    clear_graph.()

    # Pre-create nodes
    node_ids =
      1..node_count
      |> Enum.map(fn i ->
        {:ok, id} = Grapple.create_node(%{id: i})
        id
      end)

    fn ->
      # Create edges in this benchmark run
      1..edge_count
      |> Enum.each(fn i ->
        from = Enum.at(node_ids, rem(i, node_count))
        to = Enum.at(node_ids, rem(i + 1, node_count))
        Grapple.create_edge(from, to, "test_edge")
      end)
    end
  end

  Benchee.run(
    %{
      "create_100_edges (100 nodes)" => test_edge_creation.(100, 100),
      "create_1000_edges (1000 nodes)" => test_edge_creation.(1000, 1000),
      "create_5000_edges (5000 nodes)" => test_edge_creation.(5000, 5000),
      "create_10000_edges (10000 nodes)" => test_edge_creation.(10_000, 10_000)
    },
    time: 5,
    warmup: 1,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/results/scalability_edges.html"}
    ]
  )

  IO.puts("\nScalability benchmarks complete!")
  IO.puts("Results saved to bench/results/")
end
