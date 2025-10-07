defmodule Grapple.Benchmarks.GraphOperations do
  @moduledoc """
  Comprehensive benchmarks for core graph operations.

  Run with: mix run bench/graph_operations_bench.exs
  """

  # Start the application
  Application.ensure_all_started(:grapple)

  # Ensure ETS store is started
  case Grapple.Storage.EtsGraphStore.start_link() do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
  end

  # Setup: Create a moderate-sized graph for realistic testing
  setup_graph = fn node_count, edge_count ->
    # Clear existing data
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

    # Create nodes
    node_ids =
      1..node_count
      |> Enum.map(fn i ->
        {:ok, id} =
          Grapple.create_node(%{
            name: "Node#{i}",
            category: "category_#{rem(i, 10)}",
            value: i,
            role: if(rem(i, 3) == 0, do: "Engineer", else: "Manager")
          })

        id
      end)

    # Create edges
    1..edge_count
    |> Enum.each(fn i ->
      from = Enum.at(node_ids, rem(i, node_count))
      to = Enum.at(node_ids, rem(i + 1, node_count))
      label = if rem(i, 2) == 0, do: "knows", else: "reports_to"
      Grapple.create_edge(from, to, label, %{weight: rem(i, 100), since: "2024"})
    end)

    node_ids
  end

  IO.puts("Setting up test graphs...")
  small_graph = setup_graph.(100, 200)
  IO.puts("Small graph ready (100 nodes, 200 edges)")

  medium_graph_nodes = setup_graph.(1000, 2000)
  IO.puts("Medium graph ready (1000 nodes, 2000 edges)")

  # Reset to small graph for most tests
  small_graph = setup_graph.(100, 200)

  IO.puts("\nRunning benchmarks...\n")

  Benchee.run(
    %{
      "create_node" => fn ->
        Grapple.create_node(%{name: "TestNode", role: "Engineer", value: 42})
      end,
      "create_node_with_many_properties" => fn ->
        Grapple.create_node(%{
          name: "TestNode",
          role: "Engineer",
          department: "Backend",
          level: "Senior",
          location: "San Francisco",
          skills: "Elixir,GraphDB,Distributed",
          years_experience: 5,
          active: true,
          team_id: 123,
          manager_id: 456
        })
      end,
      "get_node" => fn ->
        node_id = Enum.random(small_graph)
        Grapple.get_node(node_id)
      end,
      "find_nodes_by_property (indexed)" => fn ->
        Grapple.find_nodes_by_property(:role, "Engineer")
      end,
      "find_nodes_by_property (rare value)" => fn ->
        Grapple.find_nodes_by_property(:value, 42)
      end,
      "create_edge" => fn ->
        from = Enum.random(small_graph)
        to = Enum.random(small_graph)
        Grapple.create_edge(from, to, "test_edge", %{weight: 1})
      end,
      "find_edges_by_label" => fn ->
        Grapple.find_edges_by_label("knows")
      end,
      "traverse (depth 1)" => fn ->
        node_id = Enum.random(small_graph)
        Grapple.traverse(node_id, :out, 1)
      end,
      "traverse (depth 2)" => fn ->
        node_id = Enum.random(small_graph)
        Grapple.traverse(node_id, :out, 2)
      end,
      "traverse (depth 3)" => fn ->
        node_id = Enum.random(small_graph)
        Grapple.traverse(node_id, :out, 3)
      end,
      "find_path (short)" => fn ->
        from = Enum.at(small_graph, 0)
        to = Enum.at(small_graph, 5)
        Grapple.find_path(from, to)
      end,
      "get_stats" => fn ->
        Grapple.get_stats()
      end
    },
    time: 5,
    memory_time: 2,
    warmup: 2,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/results/graph_operations.html"}
    ],
    print: [
      benchmarking: true,
      configuration: true,
      fast_warning: true
    ]
  )
end
