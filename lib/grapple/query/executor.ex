defmodule Grapple.Query.Executor do
  @moduledoc """
  Query execution engine for graph traversal and pattern matching.
  Handles distributed query execution across cluster nodes.
  """

  alias Grapple.Storage.EtsGraphStore
  alias Grapple.Cluster.NodeManager
  alias Grapple.Query.EtsOptimizer

  def execute(query) do
    # Try optimized execution first
    case EtsOptimizer.execute_optimized_query(query) do
      {:ok, result} ->
        {:ok, result}
      
      {:error, :unsupported_pattern} ->
        # Fallback to standard execution
        case parse_query(query) do
          {:ok, parsed_query} ->
            execute_parsed_query(parsed_query)
          {:error, reason} ->
            {:error, {:parse_error, reason}}
        end
      
      error ->
        error
    end
  end

  def traverse(start_node_id, direction \\ :out, depth \\ 1) do
    # Use optimized traversal for better performance
    case EtsOptimizer.optimized_traverse(start_node_id, direction, depth) do
      {:ok, result} -> {:ok, result}
      error -> error
    end
  end

  def find_path(from_node, to_node, max_depth \\ 10) do
    # Use optimized pathfinding
    case EtsOptimizer.find_shortest_paths(from_node, to_node, max_depth) do
      {:ok, [path | _]} -> {:ok, path}  # Return first path found
      {:ok, []} -> {:error, :path_not_found}
      error -> error
    end
  end

  defp parse_query(query_string) do
    # Simple query parser - expand this for full query language
    cond do
      String.starts_with?(query_string, "MATCH") ->
        parse_match_query(query_string)
      
      String.starts_with?(query_string, "CREATE") ->
        parse_create_query(query_string)
      
      true ->
        {:error, :unsupported_query}
    end
  end

  defp parse_match_query(query) do
    # Basic MATCH (n)-[r]->(m) pattern
    {:ok, %{type: :match, pattern: query}}
  end

  defp parse_create_query(query) do
    # Basic CREATE (n {prop: value}) pattern
    {:ok, %{type: :create, pattern: query}}
  end

  defp execute_parsed_query(%{type: :match, pattern: pattern}) do
    # Execute match query across distributed nodes
    nodes = NodeManager.get_cluster_info() |> Map.get(:nodes)
    
    results = 
      nodes
      |> Enum.map(fn node ->
        :rpc.call(node, __MODULE__, :execute_local_match, [pattern])
      end)
      |> Enum.flat_map(fn
        {:ok, matches} -> matches
        _ -> []
      end)
    
    {:ok, results}
  end

  defp execute_parsed_query(%{type: :create}) do
    # Handle node/edge creation
    {:ok, :created}
  end

  def execute_local_match(_pattern) do
    # Local pattern matching implementation
    {:ok, []}
  end

  defp traverse_recursive([], _direction, _depth, _visited, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp traverse_recursive(_nodes, _direction, 0, _visited, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp traverse_recursive([node_id | rest], direction, depth, visited, acc) do
    if MapSet.member?(visited, node_id) do
      traverse_recursive(rest, direction, depth, visited, acc)
    else
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          new_visited = MapSet.put(visited, node_id)
          new_acc = [node | acc]
          
          {:ok, edges} = case direction do
            :out -> EtsGraphStore.get_edges_from(node_id)
            :in -> EtsGraphStore.get_edges_to(node_id)
          end
          
          next_nodes = extract_connected_nodes(edges, direction)
          
          traverse_recursive(
            next_nodes ++ rest,
            direction,
            depth - 1,
            new_visited,
            new_acc
          )
        
        {:error, :not_found} ->
          traverse_recursive(rest, direction, depth, visited, acc)
      end
    end
  end

  defp find_path_bfs([], _target, _max_depth, _visited) do
    {:error, :path_not_found}
  end

  defp find_path_bfs([{current, path} | rest], target, max_depth, visited) do
    cond do
      current == target ->
        {:ok, path}
      
      length(path) >= max_depth ->
        find_path_bfs(rest, target, max_depth, visited)
      
      true ->
        {:ok, edges} = EtsGraphStore.get_edges_from(current)
        next_nodes = extract_connected_nodes(edges, :out)
        
        new_paths = 
          next_nodes
          |> Enum.reject(&MapSet.member?(visited, &1))
          |> Enum.map(fn node -> {node, path ++ [node]} end)
        
        new_visited = Enum.reduce(next_nodes, visited, &MapSet.put(&2, &1))
        
        find_path_bfs(rest ++ new_paths, target, max_depth, new_visited)
    end
  end

  defp extract_connected_nodes(edges, :out) do
    edges |> Enum.map(fn {_from, edge} -> edge.to end)
  end

  defp extract_connected_nodes(edges, :in) do
    edges |> Enum.map(fn {_from, edge} -> edge.from end)
  end
end