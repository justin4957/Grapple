defmodule Grapple.Query.Executor do
  @moduledoc """
  Query execution engine for graph traversal and pattern matching.
  Handles distributed query execution across cluster nodes.
  """

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
      # Return first path found
      {:ok, [path | _]} -> {:ok, path}
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
end
