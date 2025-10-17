defmodule Grapple.Analytics.Centrality do
  @moduledoc """
  Centrality algorithms for measuring node importance.

  Implements:
  - PageRank
  - Betweenness centrality
  - Closeness centrality
  - Eigenvector centrality
  """

  alias Grapple.Storage.EtsGraphStore

  @default_damping 0.85
  @default_max_iterations 100
  @default_tolerance 0.0001

  @doc """
  Calculate PageRank scores using the power iteration method.

  ## Algorithm
  PageRank(node) = (1-d)/N + d * Σ(PageRank(incoming)/out_degree(incoming))

  where:
  - d is the damping factor (probability of following a link)
  - N is the total number of nodes
  """
  def pagerank(opts \\ []) do
    damping = Keyword.get(opts, :damping_factor, @default_damping)
    max_iter = Keyword.get(opts, :max_iterations, @default_max_iterations)
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)

    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      node_count = length(nodes)

      if node_count == 0 do
        {:ok, %{}}
      else
        # Initialize all nodes with equal PageRank
        initial_rank = 1.0 / node_count
        ranks = Map.new(nodes, fn node -> {node.id, initial_rank} end)

        # Build outgoing edges map for efficiency
        outgoing = build_outgoing_edges_map(edges)

        # Iterate until convergence
        final_ranks = iterate_pagerank(ranks, outgoing, damping, max_iter, tolerance)

        # Normalize to ensure sum equals 1.0
        total = final_ranks |> Map.values() |> Enum.sum()

        normalized_ranks =
          Map.new(final_ranks, fn {node_id, rank} ->
            {node_id, rank / total}
          end)

        {:ok, normalized_ranks}
      end
    end
  end

  defp iterate_pagerank(ranks, outgoing, damping, max_iter, tolerance, iteration \\ 0) do
    if iteration >= max_iter do
      ranks
    else
      node_count = map_size(ranks)
      base_rank = (1.0 - damping) / node_count

      new_ranks =
        Map.new(ranks, fn {node_id, _old_rank} ->
          # Get all nodes that link to this node
          incoming_contribution =
            ranks
            |> Enum.reduce(0.0, fn {source_id, source_rank}, acc ->
              out_edges = Map.get(outgoing, source_id, [])

              # Check if source links to current node
              if Enum.any?(out_edges, fn edge -> edge.to == node_id end) do
                out_degree = length(out_edges)
                acc + source_rank / out_degree
              else
                acc
              end
            end)

          new_rank = base_rank + damping * incoming_contribution
          {node_id, new_rank}
        end)

      # Check for convergence
      diff =
        Enum.reduce(new_ranks, 0.0, fn {node_id, new_rank}, acc ->
          old_rank = Map.get(ranks, node_id)
          acc + abs(new_rank - old_rank)
        end)

      if diff < tolerance do
        new_ranks
      else
        iterate_pagerank(new_ranks, outgoing, damping, max_iter, tolerance, iteration + 1)
      end
    end
  end

  @doc """
  Calculate betweenness centrality for all nodes.

  Uses Brandes' algorithm for efficient computation.
  """
  def betweenness_centrality do
    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      if length(nodes) == 0 do
        {:ok, %{}}
      else
        # Initialize betweenness scores
        betweenness = Map.new(nodes, fn node -> {node.id, 0.0} end)

        # Build adjacency list
        adj_list = build_adjacency_list(edges, nodes)

        # Calculate betweenness for each source node
        final_betweenness =
          Enum.reduce(nodes, betweenness, fn source_node, acc ->
            calculate_betweenness_from_source(source_node.id, adj_list, acc)
          end)

        {:ok, final_betweenness}
      end
    end
  end

  defp calculate_betweenness_from_source(source_id, adj_list, betweenness) do
    # BFS to find shortest paths
    {predecessors, distances} = bfs_shortest_paths(source_id, adj_list)

    # Count paths and accumulate betweenness
    accumulate_betweenness(source_id, predecessors, distances, betweenness)
  end

  defp bfs_shortest_paths(source_id, adj_list) do
    queue = :queue.from_list([source_id])
    distances = %{source_id => 0}
    predecessors = %{source_id => []}

    bfs_loop(queue, adj_list, distances, predecessors)
  end

  defp bfs_loop(queue, adj_list, distances, predecessors) do
    case :queue.out(queue) do
      {{:value, current}, new_queue} ->
        current_dist = Map.get(distances, current)
        neighbors = Map.get(adj_list, current, [])

        {new_queue, distances, predecessors} =
          Enum.reduce(neighbors, {new_queue, distances, predecessors}, fn neighbor,
                                                                          {q, dist, pred} ->
            cond do
              # First time visiting this node
              !Map.has_key?(dist, neighbor) ->
                new_dist = Map.put(dist, neighbor, current_dist + 1)
                new_pred = Map.put(pred, neighbor, [current])
                new_q = :queue.in(neighbor, q)
                {new_q, new_dist, new_pred}

              # Found another shortest path
              Map.get(dist, neighbor) == current_dist + 1 ->
                new_pred = Map.update!(pred, neighbor, fn preds -> [current | preds] end)
                {q, dist, new_pred}

              # Longer path, ignore
              true ->
                {q, dist, pred}
            end
          end)

        bfs_loop(new_queue, adj_list, distances, predecessors)

      {:empty, _} ->
        {predecessors, distances}
    end
  end

  defp accumulate_betweenness(source_id, predecessors, distances, betweenness) do
    # Sort nodes by distance (descending)
    sorted_nodes =
      distances
      |> Enum.sort_by(fn {_id, dist} -> -dist end)
      |> Enum.map(fn {id, _dist} -> id end)

    # Initialize dependency scores
    dependency = Map.new(sorted_nodes, fn id -> {id, 0.0} end)

    # Accumulate dependencies bottom-up
    {_dependency, new_betweenness} =
      Enum.reduce(sorted_nodes, {dependency, betweenness}, fn node_id, {dep, bet} ->
        if node_id == source_id do
          {dep, bet}
        else
          node_dep = Map.get(dep, node_id)
          preds = Map.get(predecessors, node_id, [])

          new_dep =
            Enum.reduce(preds, dep, fn pred_id, acc_dep ->
              contribution = (1.0 + node_dep) / length(preds)
              Map.update!(acc_dep, pred_id, fn val -> val + contribution end)
            end)

          new_bet = Map.update!(bet, node_id, fn val -> val + node_dep end)

          {new_dep, new_bet}
        end
      end)

    new_betweenness
  end

  @doc """
  Calculate closeness centrality for a specific node.

  Closeness = (n-1) / Σ(shortest_distance_to_all_nodes)
  """
  def closeness_centrality(node_id) do
    case EtsGraphStore.get_node(node_id) do
      {:ok, _node} ->
        with {:ok, nodes} <- EtsGraphStore.list_nodes(),
             {:ok, edges} <- EtsGraphStore.list_edges() do
          if length(nodes) <= 1 do
            {:ok, 0.0}
          else
            adj_list = build_adjacency_list(edges, nodes)
            {_predecessors, distances} = bfs_shortest_paths(node_id, adj_list)

            # Sum distances to all reachable nodes
            total_distance =
              distances
              |> Map.values()
              |> Enum.sum()

            # Closeness is reciprocal of average distance
            n = map_size(distances)

            closeness =
              if total_distance > 0 do
                (n - 1) / total_distance
              else
                0.0
              end

            {:ok, closeness}
          end
        end

      {:error, :not_found} ->
        {:error, :node_not_found}
    end
  end

  @doc """
  Calculate eigenvector centrality for all nodes using power iteration.

  Eigenvector centrality measures node importance based on connections to other important nodes.
  A node is important if it is connected to other important nodes.

  ## Algorithm
  Uses power iteration method similar to PageRank, but without damping factor.
  Eigenvector(node) = Σ(Eigenvector(incoming) / total_incoming_connections)

  ## Options
  - `:max_iterations` - Maximum iterations for convergence (default: 100)
  - `:tolerance` - Convergence threshold (default: 0.0001)

  ## Returns
  - `{:ok, %{node_id => centrality_score}}` - Map of node IDs to centrality scores

  ## Example
      iex> {:ok, scores} = Grapple.Analytics.eigenvector_centrality()
      iex> {most_influential_id, score} = Enum.max_by(scores, fn {_id, score} -> score end)
  """
  def eigenvector_centrality(opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, @default_max_iterations)
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)

    with {:ok, nodes} <- EtsGraphStore.list_nodes(),
         {:ok, edges} <- EtsGraphStore.list_edges() do
      node_count = length(nodes)

      if node_count == 0 do
        {:ok, %{}}
      else
        # Initialize all nodes with equal centrality
        initial_centrality = 1.0 / node_count
        centralities = Map.new(nodes, fn node -> {node.id, initial_centrality} end)

        # Build adjacency list (incoming edges for each node)
        incoming_edges = build_incoming_edges_map(edges)

        # Iterate until convergence
        final_centralities =
          iterate_eigenvector(centralities, incoming_edges, max_iterations, tolerance)

        # Normalize to unit vector (L2 normalization)
        sum_of_squares =
          final_centralities
          |> Map.values()
          |> Enum.map(&(&1 * &1))
          |> Enum.sum()

        normalization_factor = :math.sqrt(sum_of_squares)

        normalized_centralities =
          if normalization_factor > 0 do
            Map.new(final_centralities, fn {node_id, centrality} ->
              {node_id, centrality / normalization_factor}
            end)
          else
            final_centralities
          end

        {:ok, normalized_centralities}
      end
    end
  end

  defp iterate_eigenvector(
         centralities,
         incoming_edges,
         max_iterations,
         tolerance,
         iteration \\ 0
       ) do
    if iteration >= max_iterations do
      centralities
    else
      # Calculate new centrality scores based on incoming connections
      new_centralities =
        Map.new(centralities, fn {node_id, _old_centrality} ->
          # Sum the centralities of all nodes that link to this node
          incoming_contribution =
            incoming_edges
            |> Map.get(node_id, [])
            |> Enum.reduce(0.0, fn edge, acc ->
              source_centrality = Map.get(centralities, edge.from, 0.0)
              acc + source_centrality
            end)

          {node_id, incoming_contribution}
        end)

      # Check for convergence
      diff =
        Enum.reduce(new_centralities, 0.0, fn {node_id, new_cent}, acc ->
          old_cent = Map.get(centralities, node_id)
          acc + abs(new_cent - old_cent)
        end)

      if diff < tolerance do
        new_centralities
      else
        iterate_eigenvector(
          new_centralities,
          incoming_edges,
          max_iterations,
          tolerance,
          iteration + 1
        )
      end
    end
  end

  # Helper functions

  defp build_outgoing_edges_map(edges) do
    Enum.group_by(edges, fn edge -> edge.from end)
  end

  defp build_incoming_edges_map(edges) do
    Enum.group_by(edges, fn edge -> edge.to end)
  end

  defp build_adjacency_list(edges, nodes) do
    # Initialize with all nodes
    initial = Map.new(nodes, fn node -> {node.id, []} end)

    # Add edges (treat as undirected for betweenness)
    Enum.reduce(edges, initial, fn edge, acc ->
      acc
      |> Map.update!(edge.from, fn neighbors -> [edge.to | neighbors] end)
      |> Map.update!(edge.to, fn neighbors -> [edge.from | neighbors] end)
    end)
  end
end
