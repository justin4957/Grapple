defmodule Grapple.Analytics.Metrics do
  @moduledoc """
  Graph-level metrics and statistics.

  Implements:
  - Graph density
  - Diameter and radius
  - Degree distribution
  - Connectivity metrics
  """

  alias Grapple.Storage.EtsGraphStore

  @doc """
  Calculate graph density.

  Density = (actual edges) / (possible edges)
  For directed graphs: possible edges = n(n-1)
  For undirected graphs: possible edges = n(n-1)/2
  """
  def graph_density do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      n = length(nodes)

      density =
        cond do
          n <= 1 ->
            0.0

          true ->
            actual_edges = length(edges)
            # Assuming directed graph
            possible_edges = n * (n - 1)
            actual_edges / possible_edges
        end

      {:ok, density}
    end
  end

  @doc """
  Calculate the diameter of the graph.

  The diameter is the longest shortest path between any pair of nodes.
  """
  def graph_diameter do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) <= 1 do
        {:ok, 0}
      else
        adj_list = build_adjacency_list(edges, nodes)

        # Calculate shortest paths from each node
        diameter =
          nodes
          |> Enum.map(fn node ->
            distances = bfs_distances(node.id, adj_list)

            # Get maximum distance from this node
            distances
            |> Map.values()
            |> Enum.max()
          end)
          |> Enum.max()

        {:ok, diameter}
      end
    end
  end

  @doc """
  Calculate degree distribution statistics.

  Returns min, max, mean, median, and standard deviation of node degrees.
  """
  def degree_distribution do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, %{min: 0, max: 0, mean: 0.0, median: 0.0, std_dev: 0.0}}
      else
        # Calculate degree for each node (out-degree + in-degree)
        degrees = calculate_degrees(nodes, edges)

        sorted_degrees = Enum.sort(degrees)
        count = length(degrees)

        stats = %{
          min: Enum.min(degrees),
          max: Enum.max(degrees),
          mean: Enum.sum(degrees) / count,
          median: calculate_median(sorted_degrees),
          std_dev: calculate_std_dev(degrees)
        }

        {:ok, stats}
      end
    end
  end

  @doc """
  Calculate the average path length of the graph.

  Average of all shortest paths between node pairs.
  """
  def average_path_length do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) <= 1 do
        {:ok, 0.0}
      else
        adj_list = build_adjacency_list(edges, nodes)

        # Calculate all pairwise distances
        total_distance =
          nodes
          |> Enum.map(fn node ->
            distances = bfs_distances(node.id, adj_list)
            Enum.sum(Map.values(distances))
          end)
          |> Enum.sum()

        n = length(nodes)
        # Total pairs is n * (n-1) for directed graph
        avg = total_distance / (n * (n - 1))

        {:ok, avg}
      end
    end
  end

  @doc """
  Calculate graph connectivity metrics.

  Returns:
  - is_connected: whether the graph is fully connected
  - component_count: number of connected components
  - largest_component_size: size of largest component
  """
  def connectivity_metrics do
    alias Grapple.Analytics.Community

    with {:ok, components} <- Community.connected_components() do
      metrics = %{
        is_connected: length(components) == 1,
        component_count: length(components),
        largest_component_size:
          if(length(components) > 0, do: components |> Enum.map(&length/1) |> Enum.max(), else: 0)
      }

      {:ok, metrics}
    end
  end

  # Helper functions

  defp build_adjacency_list(edges, nodes) do
    # Initialize with all nodes
    initial = Map.new(nodes, fn node -> {node.id, []} end)

    # Add edges (treat as undirected)
    Enum.reduce(edges, initial, fn edge, acc ->
      acc
      |> Map.update!(edge.from, fn neighbors -> [edge.to | neighbors] end)
      |> Map.update!(edge.to, fn neighbors -> [edge.from | neighbors] end)
    end)
  end

  defp bfs_distances(start_id, adj_list) do
    queue = :queue.from_list([start_id])
    distances = %{start_id => 0}

    bfs_loop(queue, adj_list, distances)
  end

  defp bfs_loop(queue, adj_list, distances) do
    case :queue.out(queue) do
      {{:value, current}, new_queue} ->
        current_dist = Map.get(distances, current)
        neighbors = Map.get(adj_list, current, [])

        {new_queue, distances} =
          Enum.reduce(neighbors, {new_queue, distances}, fn neighbor, {q, dist} ->
            if Map.has_key?(dist, neighbor) do
              {q, dist}
            else
              new_dist = Map.put(dist, neighbor, current_dist + 1)
              new_q = :queue.in(neighbor, q)
              {new_q, new_dist}
            end
          end)

        bfs_loop(new_queue, adj_list, distances)

      {:empty, _} ->
        distances
    end
  end

  defp calculate_degrees(nodes, edges) do
    # Count out-degree and in-degree for each node
    degree_map = Map.new(nodes, fn node -> {node.id, 0} end)

    degree_map =
      Enum.reduce(edges, degree_map, fn edge, acc ->
        acc
        |> Map.update!(edge.from, &(&1 + 1))
        |> Map.update!(edge.to, &(&1 + 1))
      end)

    Map.values(degree_map)
  end

  defp calculate_median(sorted_list) do
    count = length(sorted_list)
    mid = div(count, 2)

    if rem(count, 2) == 0 do
      # Even number of elements
      (Enum.at(sorted_list, mid - 1) + Enum.at(sorted_list, mid)) / 2
    else
      # Odd number of elements
      Enum.at(sorted_list, mid) * 1.0
    end
  end

  defp calculate_std_dev(values) do
    mean = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end
end
