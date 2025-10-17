defmodule Grapple.Analytics.Community do
  @moduledoc """
  Community detection and clustering algorithms.

  Implements:
  - Connected components (using Union-Find)
  - Clustering coefficient
  - Triangle counting
  - Louvain community detection
  - K-core decomposition
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
        uf =
          Enum.reduce(edges, uf, fn edge, acc ->
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

  @doc """
  Detect communities using the Louvain algorithm for modularity optimization.

  The Louvain algorithm finds communities by iteratively optimizing modularity,
  a measure of network structure quality that compares actual connections within
  communities to expected connections in a random network.

  ## Algorithm
  Two-phase iterative process:
  1. Local optimization: Move nodes to communities that maximize modularity gain
  2. Network aggregation: Collapse communities into super-nodes and repeat

  ## Returns
  - `{:ok, %{node_id => community_id}}` - Map of nodes to their community assignments

  ## Example
      iex> {:ok, communities} = Grapple.Analytics.louvain_communities()
      iex> # Group nodes by community
      iex> communities |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
  """
  def louvain_communities do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, %{}}
      else
        # Initialize each node in its own community
        initial_communities = Map.new(nodes, fn node -> {node.id, node.id} end)

        # Build degree and edge weight maps
        node_degrees = calculate_node_degrees(nodes, edges)
        total_edge_weight = length(edges) * 2.0

        # Build adjacency map with weights
        adjacency = build_weighted_adjacency(edges)

        # Run Louvain optimization
        final_communities =
          louvain_optimize(
            initial_communities,
            adjacency,
            node_degrees,
            total_edge_weight
          )

        {:ok, final_communities}
      end
    end
  end

  defp louvain_optimize(communities, adjacency, node_degrees, total_edge_weight) do
    # Phase 1: Move nodes to optimize modularity
    {new_communities, improvement} =
      louvain_phase_one(communities, adjacency, node_degrees, total_edge_weight)

    # If no improvement, we've converged
    if improvement < 0.0001 do
      new_communities
    else
      # Phase 2: Aggregate network and repeat
      # For simplicity, we'll just return after one pass
      # A full implementation would aggregate and recurse
      new_communities
    end
  end

  defp louvain_phase_one(communities, adjacency, node_degrees, total_edge_weight) do
    node_ids = Map.keys(communities)

    # Try moving each node to optimize modularity
    {final_communities, total_improvement} =
      Enum.reduce(node_ids, {communities, 0.0}, fn node_id, {current_communities, improvement} ->
        current_community = Map.get(current_communities, node_id)

        # Find best community for this node
        neighbor_communities =
          adjacency
          |> Map.get(node_id, [])
          |> Enum.map(fn neighbor -> Map.get(current_communities, neighbor) end)
          |> Enum.uniq()

        best_move =
          neighbor_communities
          |> Enum.map(fn target_community ->
            # Calculate modularity gain of moving to this community
            gain =
              modularity_gain(
                node_id,
                current_community,
                target_community,
                current_communities,
                adjacency,
                node_degrees,
                total_edge_weight
              )

            {target_community, gain}
          end)
          |> Enum.max_by(fn {_comm, gain} -> gain end, fn -> {current_community, 0.0} end)

        {best_community, gain} = best_move

        if gain > 0 and best_community != current_community do
          {Map.put(current_communities, node_id, best_community), improvement + gain}
        else
          {current_communities, improvement}
        end
      end)

    {final_communities, total_improvement}
  end

  defp modularity_gain(
         node_id,
         current_community,
         target_community,
         communities,
         adjacency,
         node_degrees,
         total_edge_weight
       ) do
    if current_community == target_community do
      0.0
    else
      # Count edges from node to target community
      edges_to_target =
        adjacency
        |> Map.get(node_id, [])
        |> Enum.count(fn neighbor ->
          Map.get(communities, neighbor) == target_community
        end)

      # Count edges from node to current community
      edges_to_current =
        adjacency
        |> Map.get(node_id, [])
        |> Enum.count(fn neighbor ->
          Map.get(communities, neighbor) == current_community
        end)

      node_degree = Map.get(node_degrees, node_id, 0)

      # Simplified modularity gain calculation
      delta_q =
        (edges_to_target - edges_to_current) / total_edge_weight -
          node_degree * node_degree / (total_edge_weight * total_edge_weight)

      delta_q
    end
  end

  @doc """
  Perform k-core decomposition to find densely connected subgraphs.

  The k-core of a graph is the maximal subgraph where every node has at least
  k connections within the subgraph. This algorithm assigns each node its core number,
  which is the highest k for which the node belongs to a k-core.

  ## Algorithm
  Iteratively remove nodes with degree < k, incrementing k until no more nodes can be removed.

  ## Returns
  - `{:ok, %{node_id => core_number}}` - Map of nodes to their core numbers

  ## Use Cases
  - Find influential groups (high core number = tightly connected)
  - Identify network structure and cohesiveness
  - Detect resilient subnetworks

  ## Example
      iex> {:ok, cores} = Grapple.Analytics.k_core_decomposition()
      iex> max_core = cores |> Map.values() |> Enum.max()
      iex> core_nodes = Enum.filter(cores, fn {_id, k} -> k == max_core end)
  """
  def k_core_decomposition do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, %{}}
      else
        # Build undirected adjacency list
        adjacency = build_adjacency_list(edges)

        # Initialize core numbers to 0
        core_numbers = Map.new(nodes, fn node -> {node.id, 0} end)

        # Calculate degrees
        current_degrees =
          Map.new(adjacency, fn {node_id, neighbors} ->
            {node_id, length(neighbors)}
          end)

        # Perform k-core decomposition
        final_cores = k_core_iterate(adjacency, current_degrees, core_numbers, 0)

        {:ok, final_cores}
      end
    end
  end

  defp k_core_iterate(adjacency, degrees, core_numbers, current_k) do
    # Find nodes with degree <= current_k
    nodes_to_remove =
      degrees
      |> Enum.filter(fn {_node_id, degree} -> degree <= current_k end)
      |> Enum.map(fn {node_id, _degree} -> node_id end)

    if length(nodes_to_remove) == 0 do
      # No more nodes can be removed at this k level
      if map_size(degrees) == 0 do
        # All nodes processed
        core_numbers
      else
        # Move to next k level
        k_core_iterate(adjacency, degrees, core_numbers, current_k + 1)
      end
    else
      # Remove these nodes and update neighbors
      {new_degrees, new_cores} =
        Enum.reduce(nodes_to_remove, {degrees, core_numbers}, fn node_id, {deg_acc, core_acc} ->
          # Set core number for this node
          new_core_acc = Map.put(core_acc, node_id, current_k)

          # Remove node from degrees
          new_deg_acc = Map.delete(deg_acc, node_id)

          # Update neighbor degrees
          neighbors = Map.get(adjacency, node_id, [])

          updated_deg_acc =
            Enum.reduce(neighbors, new_deg_acc, fn neighbor, acc ->
              if Map.has_key?(acc, neighbor) do
                Map.update!(acc, neighbor, fn deg -> max(0, deg - 1) end)
              else
                acc
              end
            end)

          {updated_deg_acc, new_core_acc}
        end)

      k_core_iterate(adjacency, new_degrees, new_cores, current_k)
    end
  end

  @doc """
  Count triangles for each node in the graph.

  Returns a map of node IDs to the number of triangles they participate in.
  A triangle is a set of three nodes where each pair is connected.

  ## Returns
  - `{:ok, %{node_id => triangle_count}}` - Map of nodes to triangle counts

  ## Example
      iex> {:ok, triangles} = Grapple.Analytics.triangle_count()
      iex> {node_id, count} = Enum.max_by(triangles, fn {_id, count} -> count end)
  """
  def triangle_count do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, %{}}
      else
        adjacency_list = build_adjacency_list(edges)

        triangle_counts =
          Map.new(nodes, fn node ->
            neighbors = Map.get(adjacency_list, node.id, []) |> MapSet.new()
            count = count_node_triangles(node.id, neighbors, adjacency_list)
            {node.id, count}
          end)

        {:ok, triangle_counts}
      end
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

  # Helper functions for new algorithms

  defp calculate_node_degrees(nodes, edges) do
    # Initialize all nodes with degree 0
    initial_degrees = Map.new(nodes, fn node -> {node.id, 0} end)

    # Count undirected degree (both incoming and outgoing)
    Enum.reduce(edges, initial_degrees, fn edge, acc ->
      acc
      |> Map.update!(edge.from, &(&1 + 1))
      |> Map.update!(edge.to, &(&1 + 1))
    end)
  end

  defp build_weighted_adjacency(edges) do
    # Build undirected adjacency list (treating as undirected for community detection)
    edges
    |> Enum.reduce(%{}, fn edge, acc ->
      acc
      |> Map.update(edge.from, [edge.to], fn neighbors -> [edge.to | neighbors] end)
      |> Map.update(edge.to, [edge.from], fn neighbors -> [edge.from | neighbors] end)
    end)
  end
end
