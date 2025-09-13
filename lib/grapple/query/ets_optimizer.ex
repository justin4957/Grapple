defmodule Grapple.Query.EtsOptimizer do
  @moduledoc """
  ETS-optimized query execution engine.
  Uses ETS match specifications and indexes for high-performance queries.
  """

  alias Grapple.Storage.EtsGraphStore

  def execute_optimized_query(query) do
    case parse_and_optimize(query) do
      {:ok, optimized_plan} ->
        execute_plan(optimized_plan)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def find_pattern(pattern) do
    case pattern do
      %{type: :node_property, property: {key, value}} ->
        EtsGraphStore.find_nodes_by_property(key, value)
      
      %{type: :edge_label, label: label} ->
        EtsGraphStore.find_edges_by_label(label)
      
      %{type: :relationship, from: from_pattern, to: to_pattern, edge: edge_pattern} ->
        execute_relationship_pattern(from_pattern, to_pattern, edge_pattern)
      
      _ ->
        {:error, :unsupported_pattern}
    end
  end

  def batch_get_nodes(node_ids) when is_list(node_ids) do
    # Optimized batch retrieval using ETS select
    match_spec = [{
      {:"$1", :"$2"}, 
      [{:orelse, Enum.map(node_ids, fn id -> {:==, :"$1", id} end)}],
      [:"$2"]
    }]
    
    results = :ets.select(:grapple_nodes, match_spec)
    {:ok, results}
  end

  def optimized_traverse(start_node_id, direction, depth, filters \\ []) do
    traverse_with_pruning(start_node_id, direction, depth, filters, MapSet.new(), [])
  end

  def find_shortest_paths(from_node, to_node, max_depth \\ 10) do
    # Bidirectional BFS for optimal performance
    if from_node == to_node do
      {:ok, [[from_node]]}
    else
      bidirectional_bfs(from_node, to_node, max_depth)
    end
  end

  def aggregate_query(nodes, aggregation_type, property \\ nil) do
    case aggregation_type do
      :count ->
        {:ok, length(nodes)}
      
      :avg when property != nil ->
        values = extract_numeric_property(nodes, property)
        if length(values) > 0 do
          avg = Enum.sum(values) / length(values)
          {:ok, avg}
        else
          {:ok, 0}
        end
      
      :sum when property != nil ->
        values = extract_numeric_property(nodes, property)
        {:ok, Enum.sum(values)}
      
      :max when property != nil ->
        values = extract_numeric_property(nodes, property)
        if length(values) > 0 do
          {:ok, Enum.max(values)}
        else
          {:ok, nil}
        end
      
      :min when property != nil ->
        values = extract_numeric_property(nodes, property)
        if length(values) > 0 do
          {:ok, Enum.min(values)}
        else
          {:ok, nil}
        end
      
      _ ->
        {:error, :unsupported_aggregation}
    end
  end

  def cached_subgraph(node_id, depth) do
    cache_key = {node_id, depth}
    
    case :ets.lookup(:grapple_query_cache, cache_key) do
      [{^cache_key, cached_result}] ->
        {:ok, :cached, cached_result}
      
      [] ->
        case compute_subgraph(node_id, depth) do
          {:ok, result} ->
            # Cache result with TTL (simple version)
            :ets.insert(:grapple_query_cache, {cache_key, result})
            {:ok, :computed, result}
          
          error ->
            error
        end
    end
  end

  # Private functions
  defp parse_and_optimize(query) do
    # Simple optimization: detect index-friendly patterns
    cond do
      String.contains?(query, "FIND NODES") ->
        {:ok, %{type: :indexed_node_lookup, query: query}}
      
      String.contains?(query, "FIND EDGES") ->
        {:ok, %{type: :indexed_edge_lookup, query: query}}
      
      String.contains?(query, "MATCH") ->
        {:ok, %{type: :pattern_match, query: query}}
      
      true ->
        {:ok, %{type: :general, query: query}}
    end
  end

  defp execute_plan(%{type: :indexed_node_lookup, query: query}) do
    # Extract property and value from query
    case Regex.run(~r/FIND NODES (\w+) (.+)/, query) do
      [_, property, value] ->
        prop_atom = String.to_atom(property)
        EtsGraphStore.find_nodes_by_property(prop_atom, value)
      
      _ ->
        {:error, :invalid_query}
    end
  end

  defp execute_plan(%{type: :indexed_edge_lookup, query: query}) do
    case Regex.run(~r/FIND EDGES (.+)/, query) do
      [_, label] ->
        EtsGraphStore.find_edges_by_label(String.trim(label))
      
      _ ->
        {:error, :invalid_query}
    end
  end

  defp execute_plan(%{type: :pattern_match, query: _query}) do
    # Implement pattern matching optimization
    {:ok, []}
  end

  defp execute_plan(%{type: :general, query: _query}) do
    # Fallback to standard execution
    {:ok, []}
  end

  defp execute_relationship_pattern(from_pattern, to_pattern, edge_pattern) do
    # Find candidate nodes for 'from' pattern
    {:ok, from_nodes} = case from_pattern do
      %{properties: props} when map_size(props) > 0 ->
        {key, value} = Enum.take(props, 1) |> List.first()
        EtsGraphStore.find_nodes_by_property(key, value)
      
      _ ->
        # Get all nodes (expensive, should be optimized)
        get_all_nodes()
    end
    
    # Find candidate edges based on label
    {:ok, candidate_edges} = case edge_pattern do
      %{label: label} when label != nil ->
        EtsGraphStore.find_edges_by_label(label)
      
      _ ->
        get_all_edges()
    end
    
    # Filter edges that start from candidate nodes
    from_node_ids = MapSet.new(from_nodes, fn node -> node.id end)
    matching_edges = 
      candidate_edges
      |> Enum.filter(fn edge -> MapSet.member?(from_node_ids, edge.from) end)
    
    # Get target nodes and filter by to_pattern
    to_node_ids = matching_edges |> Enum.map(fn edge -> edge.to end) |> Enum.uniq()
    {:ok, to_nodes} = batch_get_nodes(to_node_ids)
    
    # Filter to_nodes by pattern
    filtered_to_nodes = case to_pattern do
      %{properties: props} when map_size(props) > 0 ->
        Enum.filter(to_nodes, fn node ->
          Enum.all?(props, fn {key, value} ->
            Map.get(node.properties, key) == value
          end)
        end)
      
      _ ->
        to_nodes
    end
    
    {:ok, {from_nodes, matching_edges, filtered_to_nodes}}
  end

  defp traverse_with_pruning(node_id, direction, depth, filters, visited, acc) when depth > 0 do
    if MapSet.member?(visited, node_id) do
      {:ok, acc}
    else
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          # Apply filters
          if passes_filters?(node, filters) do
            new_visited = MapSet.put(visited, node_id)
            new_acc = [node | acc]
            
            # Get connected nodes
            {:ok, edges} = case direction do
              :out -> EtsGraphStore.get_edges_from(node_id)
              :in -> EtsGraphStore.get_edges_to(node_id)
            end
            
            connected_nodes = edges |> Enum.map(fn {_from, edge} ->
              case direction do
                :out -> edge.to
                :in -> edge.from
              end
            end)
            
            # Recursively traverse
            results = 
              connected_nodes
              |> Enum.map(fn next_node ->
                traverse_with_pruning(next_node, direction, depth - 1, filters, new_visited, [])
              end)
            
            combined_results = 
              results
              |> Enum.flat_map(fn
                {:ok, nodes} -> nodes
                _ -> []
              end)
            
            {:ok, new_acc ++ combined_results}
          else
            {:ok, acc}
          end
        
        {:error, :not_found} ->
          {:ok, acc}
      end
    end
  end

  defp traverse_with_pruning(_node_id, _direction, 0, _filters, _visited, acc) do
    {:ok, acc}
  end

  defp bidirectional_bfs(from_node, to_node, max_depth) do
    forward_queue = [{from_node, [from_node], 0}]
    backward_queue = [{to_node, [to_node], 0}]
    forward_visited = MapSet.new([from_node])
    backward_visited = MapSet.new([to_node])
    
    bfs_search(forward_queue, backward_queue, forward_visited, backward_visited, max_depth, [])
  end

  defp bfs_search([], [], _forward_visited, _backward_visited, _max_depth, paths) do
    if length(paths) > 0 do
      {:ok, paths}
    else
      {:error, :path_not_found}
    end
  end

  defp bfs_search(forward_queue, backward_queue, forward_visited, backward_visited, max_depth, paths) do
    # Process forward direction
    {new_forward_queue, new_forward_visited, new_paths1} = 
      process_bfs_queue(forward_queue, backward_visited, forward_visited, :forward, max_depth)
    
    # Process backward direction  
    {new_backward_queue, new_backward_visited, new_paths2} = 
      process_bfs_queue(backward_queue, new_forward_visited, backward_visited, :backward, max_depth)
    
    all_paths = paths ++ new_paths1 ++ new_paths2
    
    if length(all_paths) > 0 do
      {:ok, all_paths}
    else
      bfs_search(new_forward_queue, new_backward_queue, new_forward_visited, new_backward_visited, max_depth, all_paths)
    end
  end

  defp process_bfs_queue(queue, other_visited, visited, direction, max_depth) do
    {new_queue, new_visited, paths} = 
      queue
      |> Enum.reduce({[], visited, []}, fn {current, path, depth}, {acc_queue, acc_visited, acc_paths} ->
        if depth >= max_depth do
          {acc_queue, acc_visited, acc_paths}
        else
          {:ok, edges} = case direction do
            :forward -> EtsGraphStore.get_edges_from(current)
            :backward -> EtsGraphStore.get_edges_to(current)
          end
          
          neighbors = edges |> Enum.map(fn {_from, edge} ->
            case direction do
              :forward -> edge.to
              :backward -> edge.from
            end
          end)
          
          Enum.reduce(neighbors, {acc_queue, acc_visited, acc_paths}, fn neighbor, {q_acc, v_acc, p_acc} ->
            cond do
              MapSet.member?(v_acc, neighbor) ->
                {q_acc, v_acc, p_acc}
              
              MapSet.member?(other_visited, neighbor) ->
                # Found connection!
                new_path = case direction do
                  :forward -> path ++ [neighbor]
                  :backward -> [neighbor | path]
                end
                {q_acc, MapSet.put(v_acc, neighbor), [new_path | p_acc]}
              
              true ->
                new_path = case direction do
                  :forward -> path ++ [neighbor]
                  :backward -> [neighbor | path]
                end
                {[{neighbor, new_path, depth + 1} | q_acc], MapSet.put(v_acc, neighbor), p_acc}
            end
          end)
        end
      end)
    
    {new_queue, new_visited, paths}
  end

  defp passes_filters?(node, filters) do
    Enum.all?(filters, fn filter ->
      case filter do
        {:property, key, value} ->
          Map.get(node.properties, key) == value
        
        {:property_exists, key} ->
          Map.has_key?(node.properties, key)
        
        _ ->
          true
      end
    end)
  end

  defp extract_numeric_property(nodes, property) do
    nodes
    |> Enum.map(fn node -> Map.get(node.properties, property) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn value -> is_number(value) or is_binary(value) end)
    |> Enum.map(fn value ->
      case value do
        n when is_number(n) -> n
        s when is_binary(s) ->
          case Float.parse(s) do
            {num, ""} -> num
            _ ->
              case Integer.parse(s) do
                {num, ""} -> num
                _ -> nil
              end
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp compute_subgraph(node_id, depth) do
    case EtsGraphStore.get_node(node_id) do
      {:ok, _node} ->
        traverse_for_subgraph(node_id, depth, MapSet.new(), [])
      
      error ->
        error
    end
  end

  defp traverse_for_subgraph(node_id, depth, visited, acc) when depth > 0 do
    if MapSet.member?(visited, node_id) do
      {:ok, acc}
    else
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          new_visited = MapSet.put(visited, node_id)
          new_acc = [node | acc]
          
          {:ok, edges} = EtsGraphStore.get_edges_from(node_id)
          connected_nodes = edges |> Enum.map(fn {_from, edge} -> edge.to end)
          
          results = 
            connected_nodes
            |> Enum.map(fn next_node ->
              traverse_for_subgraph(next_node, depth - 1, new_visited, [])
            end)
          
          combined_results = 
            results
            |> Enum.flat_map(fn
              {:ok, nodes} -> nodes
              _ -> []
            end)
          
          {:ok, new_acc ++ combined_results}
        
        error ->
          error
      end
    end
  end

  defp traverse_for_subgraph(_node_id, 0, _visited, acc) do
    {:ok, acc}
  end

  # Helper functions for getting all nodes/edges (should be optimized with proper indexes)
  defp get_all_nodes do
    match_spec = [{{:"$1", :"$2"}, [], [:"$2"]}]
    results = :ets.select(:grapple_nodes, match_spec)
    {:ok, results}
  end

  defp get_all_edges do
    match_spec = [{{:"$1", :"$2"}, [], [:"$2"]}]
    results = :ets.select(:grapple_edges, match_spec)
    {:ok, results}
  end

  # Initialize query cache table
  def init_cache do
    case :ets.info(:grapple_query_cache) do
      :undefined ->
        :ets.new(:grapple_query_cache, [:set, :named_table, :public, {:read_concurrency, true}])
      
      _ ->
        :grapple_query_cache
    end
  end
end