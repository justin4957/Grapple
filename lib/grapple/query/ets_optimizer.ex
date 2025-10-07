defmodule Grapple.Query.EtsOptimizer do
  @moduledoc """
  ETS-optimized query execution engine for Grapple.

  Provides highly optimized graph traversal and query operations using
  direct ETS table access for maximum performance.
  """

  alias Grapple.Storage.EtsGraphStore

  # Query cache for frequently accessed patterns
  @cache_table :grapple_query_cache

  @doc """
  Initialize the query cache.
  """
  def init_cache do
    case :ets.info(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table, {:read_concurrency, true}])

      _ ->
        :ok
    end
  end

  @doc """
  Execute an optimized query using ETS direct access.

  Falls back to standard execution for unsupported patterns.
  """
  def execute_optimized_query(query_string) when is_binary(query_string) do
    case parse_optimizable_query(query_string) do
      {:match_all} ->
        get_all_nodes_optimized()

      {:match_property, key, value} ->
        EtsGraphStore.find_nodes_by_property(key, value)

      {:match_edges_by_label, label} ->
        EtsGraphStore.find_edges_by_label(label)

      {:count_nodes} ->
        {:ok, count_nodes_optimized()}

      {:count_edges} ->
        {:ok, count_edges_optimized()}

      {:unsupported} ->
        {:error, :unsupported_pattern}
    end
  end

  @doc """
  Optimized graph traversal using direct ETS access.

  Uses breadth-first search with ETS table scanning for optimal performance.
  """
  def optimized_traverse(start_node_id, direction \\ :out, depth \\ 1) do
    case EtsGraphStore.get_node(start_node_id) do
      {:ok, _} ->
        cache_key = {:traverse, start_node_id, direction, depth}

        case get_from_cache(cache_key) do
          {:ok, cached_result} ->
            {:ok, cached_result}

          :not_found ->
            result = perform_optimized_traverse(start_node_id, direction, depth)
            cache_result(cache_key, result)
            result
        end

      {:error, :not_found} ->
        {:error, :node_not_found}
    end
  end

  @doc """
  Find shortest paths using optimized bidirectional BFS.

  Returns multiple paths if they exist at the same distance.
  """
  def find_shortest_paths(from_node, to_node, max_depth \\ 10) do
    if from_node == to_node do
      {:ok, [[from_node]]}
    else
      case {EtsGraphStore.get_node(from_node), EtsGraphStore.get_node(to_node)} do
        {{:ok, _}, {:ok, _}} ->
          cache_key = {:shortest_paths, from_node, to_node, max_depth}

          case get_from_cache(cache_key) do
            {:ok, cached_result} ->
              {:ok, cached_result}

            :not_found ->
              result = perform_bidirectional_search(from_node, to_node, max_depth)
              cache_result(cache_key, result)
              result
          end

        _ ->
          {:error, :node_not_found}
      end
    end
  end

  @doc """
  Get neighbors of a node with optimized ETS access.
  """
  def get_neighbors_optimized(node_id, direction \\ :both) do
    case direction do
      :out ->
        case EtsGraphStore.get_edges_from(node_id) do
          {:ok, edges} ->
            neighbors = edges |> Enum.map(fn {_from, edge} -> edge.to end) |> Enum.uniq()
            {:ok, neighbors}

          error ->
            error
        end

      :in ->
        case EtsGraphStore.get_edges_to(node_id) do
          {:ok, edges} ->
            neighbors = edges |> Enum.map(fn {from, _edge} -> from end) |> Enum.uniq()
            {:ok, neighbors}

          error ->
            error
        end

      :both ->
        {:ok, out_neighbors} = get_neighbors_optimized(node_id, :out)
        {:ok, in_neighbors} = get_neighbors_optimized(node_id, :in)
        {:ok, Enum.uniq(out_neighbors ++ in_neighbors)}
    end
  end

  @doc """
  Clear the query cache.
  """
  def clear_cache do
    case :ets.info(@cache_table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(@cache_table)
    end
  end

  # Private functions

  defp parse_optimizable_query(query_string) do
    query = String.trim(query_string) |> String.upcase()

    cond do
      query == "MATCH (N) RETURN N" ->
        {:match_all}

      Regex.match?(~r/MATCH \(N \{(\w+): ['""]([^'""]+)['"]\}\) RETURN N/i, query) ->
        case Regex.run(~r/MATCH \(N \{(\w+): ['""]([^'""]+)['"]\}\) RETURN N/i, query_string) do
          [_, key, value] -> {:match_property, String.to_atom(key), value}
          _ -> {:unsupported}
        end

      Regex.match?(~r/MATCH \(\)-\[:(\w+)\]-\(\) RETURN/i, query) ->
        case Regex.run(~r/MATCH \(\)-\[:(\w+)\]-\(\) RETURN/i, query_string) do
          [_, label] -> {:match_edges_by_label, label}
          _ -> {:unsupported}
        end

      query == "RETURN COUNT(*)" or String.contains?(query, "COUNT(N)") ->
        {:count_nodes}

      String.contains?(query, "COUNT") and String.contains?(query, "EDGE") ->
        {:count_edges}

      true ->
        {:unsupported}
    end
  end

  defp get_all_nodes_optimized do
    try do
      nodes =
        :ets.tab2list(:grapple_nodes)
        |> Enum.map(fn {_id, node_data} -> node_data end)

      {:ok, nodes}
    catch
      _ -> {:error, :table_access_failed}
    end
  end

  defp count_nodes_optimized do
    try do
      :ets.info(:grapple_nodes, :size) || 0
    catch
      _ -> 0
    end
  end

  defp count_edges_optimized do
    try do
      :ets.info(:grapple_edges, :size) || 0
    catch
      _ -> 0
    end
  end

  defp perform_optimized_traverse(start_node_id, direction, depth) do
    # Start node is already visited
    visited = MapSet.new([start_node_id])

    # Get initial neighbors at depth 1
    {:ok, initial_neighbors} = get_neighbors_optimized(start_node_id, direction)
    queue = Enum.map(initial_neighbors, fn neighbor -> {neighbor, 1} end)
    results = []

    traverse_bfs_optimized(queue, visited, results, direction, depth)
  end

  defp traverse_bfs_optimized([], _visited, results, _direction, _max_depth) do
    {:ok, Enum.reverse(results)}
  end

  defp traverse_bfs_optimized(
         [{node_id, current_depth} | rest],
         visited,
         results,
         direction,
         max_depth
       ) do
    if MapSet.member?(visited, node_id) or current_depth > max_depth do
      traverse_bfs_optimized(rest, visited, results, direction, max_depth)
    else
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          new_visited = MapSet.put(visited, node_id)
          # Include nodes found at the current depth (neighbors at depth 1, etc.)
          new_results = [node | results]

          # Only continue traversing if we haven't reached max depth
          {new_queue, next_visited} =
            if current_depth < max_depth do
              {:ok, neighbors} = get_neighbors_optimized(node_id, direction)
              next_level = Enum.map(neighbors, fn neighbor -> {neighbor, current_depth + 1} end)
              {rest ++ next_level, new_visited}
            else
              {rest, new_visited}
            end

          traverse_bfs_optimized(new_queue, next_visited, new_results, direction, max_depth)

        _ ->
          traverse_bfs_optimized(rest, visited, results, direction, max_depth)
      end
    end
  end

  defp perform_bidirectional_search(from_node, to_node, max_depth) do
    # For now, implement simple BFS - can optimize to true bidirectional later
    queue = [{from_node, [from_node], 0}]
    visited = MapSet.new([from_node])

    find_all_paths_bfs(queue, visited, to_node, max_depth, [])
  end

  defp find_all_paths_bfs([], _visited, _target, _max_depth, paths) do
    {:ok, paths}
  end

  defp find_all_paths_bfs([{current, path, depth} | rest], visited, target, max_depth, paths) do
    cond do
      current == target ->
        find_all_paths_bfs(rest, visited, target, max_depth, [path | paths])

      depth >= max_depth ->
        find_all_paths_bfs(rest, visited, target, max_depth, paths)

      true ->
        {:ok, neighbors} = get_neighbors_optimized(current, :both)

        new_paths =
          neighbors
          |> Enum.reject(&MapSet.member?(visited, &1))
          |> Enum.map(fn neighbor -> {neighbor, path ++ [neighbor], depth + 1} end)

        new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))

        find_all_paths_bfs(rest ++ new_paths, new_visited, target, max_depth, paths)
    end
  end

  defp get_from_cache(key) do
    try do
      case :ets.lookup(@cache_table, key) do
        [{^key, result, timestamp}] ->
          # Simple cache expiry (5 minutes)
          if System.system_time(:second) - timestamp < 300 do
            {:ok, result}
          else
            :ets.delete(@cache_table, key)
            :not_found
          end

        [] ->
          :not_found
      end
    catch
      _ -> :not_found
    end
  end

  defp cache_result(key, {:ok, result}) do
    try do
      :ets.insert(@cache_table, {key, result, System.system_time(:second)})
    catch
      _ -> :ok
    end

    {:ok, result}
  end

  defp cache_result(_key, error), do: error
end
