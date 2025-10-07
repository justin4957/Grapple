defmodule Grapple.Analytics.Community do
  @moduledoc """
  Community detection and clustering algorithms.

  Implements:
  - Connected components (using Union-Find)
  - Clustering coefficient
  - Triangle counting
  """

  alias Grapple.Storage.EtsGraphStore

  @doc """
  Find all connected components using Union-Find algorithm.

  Returns a list of components, where each component is a list of node IDs.
  """
  def connected_components do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, []}
      else
        # Initialize Union-Find structure
        uf = initialize_union_find(nodes)

        # Union all connected nodes
        uf = Enum.reduce(edges, uf, fn edge, acc ->
          union(acc, edge.from, edge.to)
        end)

        # Group nodes by their root
        components =
          nodes
          |> Enum.group_by(fn node -> find(uf, node.id) end)
          |> Map.values()
          |> Enum.map(fn component -> Enum.map(component, & &1.id) end)
          |> Enum.sort_by(&length/1, :desc)

        {:ok, components}
      end
    end
  end

  @doc """
  Calculate global clustering coefficient for the graph.

  Global clustering coefficient = (3 * number of triangles) / number of connected triples
  """
  def clustering_coefficient do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, 0.0}
      else
        adj_list = build_adjacency_list(edges)

        # Count triangles and triples for each node
        {triangle_count, triple_count} =
          Enum.reduce(nodes, {0, 0}, fn node, {tri, trip} ->
            neighbors = Map.get(adj_list, node.id, []) |> MapSet.new()
            degree = MapSet.size(neighbors)

            # Count connected triples (pairs of neighbors)
            triples = div(degree * (degree - 1), 2)

            # Count triangles (neighbors that are also connected)
            triangles = count_node_triangles(node.id, neighbors, adj_list)

            {tri + triangles, trip + triples}
          end)

        coefficient =
          if triple_count > 0 do
            # Each triangle is counted 3 times (once for each vertex)
            triangle_count / triple_count
          else
            0.0
          end

        {:ok, coefficient}
      end
    end
  end

  @doc """
  Calculate local clustering coefficient for a specific node.

  Local clustering = (number of edges between neighbors) / (max possible edges between neighbors)
  """
  def local_clustering_coefficient(node_id) do
    case EtsGraphStore.get_node(node_id) do
      {:ok, _node} ->
        with {:ok, edges} <- EtsGraphStore.list_edges() do
          adj_list = build_adjacency_list(edges)
          neighbors = Map.get(adj_list, node_id, []) |> MapSet.new()
          degree = MapSet.size(neighbors)

          coefficient =
            if degree < 2 do
              0.0
            else
              # Count edges between neighbors
              edges_between = count_edges_between_neighbors(neighbors, adj_list)

              # Maximum possible edges between k neighbors is k(k-1)/2
              max_edges = div(degree * (degree - 1), 2)

              edges_between / max_edges
            end

          {:ok, coefficient}
        end

      {:error, :not_found} ->
        {:error, :node_not_found}
    end
  end

  # Union-Find implementation

  defp initialize_union_find(nodes) do
    # parent[i] = i initially (each node is its own parent)
    # rank[i] = 0 initially (used for optimization)
    %{
      parent: Map.new(nodes, fn node -> {node.id, node.id} end),
      rank: Map.new(nodes, fn node -> {node.id, 0} end)
    }
  end

  defp find(%{parent: parent} = uf, node_id) do
    parent_id = Map.get(parent, node_id, node_id)

    if parent_id == node_id do
      node_id
    else
      # Path compression: make node point directly to root
      root = find(uf, parent_id)
      root
    end
  end

  defp union(%{parent: parent, rank: rank} = uf, node1, node2) do
    root1 = find(uf, node1)
    root2 = find(uf, node2)

    if root1 == root2 do
      uf
    else
      rank1 = Map.get(rank, root1, 0)
      rank2 = Map.get(rank, root2, 0)

      # Union by rank: attach smaller tree under larger tree
      cond do
        rank1 > rank2 ->
          %{uf | parent: Map.put(parent, root2, root1)}

        rank1 < rank2 ->
          %{uf | parent: Map.put(parent, root1, root2)}

        true ->
          %{
            uf
            | parent: Map.put(parent, root2, root1),
              rank: Map.update!(rank, root1, &(&1 + 1))
          }
      end
    end
  end

  # Helper functions

  defp build_adjacency_list(edges) do
    # Build undirected adjacency list
    edges
    |> Enum.reduce(%{}, fn edge, acc ->
      acc
      |> Map.update(edge.from, [edge.to], fn neighbors -> [edge.to | neighbors] end)
      |> Map.update(edge.to, [edge.from], fn neighbors -> [edge.from | neighbors] end)
    end)
  end

  defp count_node_triangles(_node_id, neighbors, adj_list) do
    # For each pair of neighbors, check if they're connected
    neighbor_list = MapSet.to_list(neighbors)

    Enum.reduce(neighbor_list, 0, fn neighbor1, count ->
      neighbor1_neighbors = Map.get(adj_list, neighbor1, []) |> MapSet.new()

      # Count how many other neighbors of node are also neighbors of neighbor1
      common =
        neighbors
        |> MapSet.intersection(neighbor1_neighbors)
        |> MapSet.size()

      count + common
    end)
    # Each triangle is counted twice, so divide by 2
    |> div(2)
  end

  defp count_edges_between_neighbors(neighbors, adj_list) do
    neighbor_list = MapSet.to_list(neighbors)

    Enum.reduce(neighbor_list, 0, fn neighbor, count ->
      neighbor_neighbors = Map.get(adj_list, neighbor, []) |> MapSet.new()

      # Count how many of the other neighbors are connected to this neighbor
      common = MapSet.intersection(neighbors, neighbor_neighbors) |> MapSet.size()

      count + common
    end)
    # Each edge is counted twice (once from each end)
    |> div(2)
  end
end
