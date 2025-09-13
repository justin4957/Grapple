defmodule Grapple.Distributed.PlacementEngine do
  @moduledoc """
  Ephemeral-first data placement engine for distributed graph storage.
  
  Handles intelligent placement of nodes/edges across the cluster based on:
  - Access patterns and locality
  - Computational requirements
  - Memory pressure and resource availability
  - Network topology awareness
  """

  use GenServer
  alias Grapple.Storage.EtsGraphStore
  alias Grapple.Distributed.{LifecycleManager, ClusterManager}

  defstruct [
    :local_node,
    :placement_strategies,
    :resource_monitor,
    :access_patterns,
    :locality_cache
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def place_data(key, data, classification \\ :ephemeral, opts \\ []) do
    GenServer.call(__MODULE__, {:place_data, key, data, classification, opts})
  end

  def relocate_data(key, new_classification) do
    GenServer.call(__MODULE__, {:relocate_data, key, new_classification})
  end

  def get_data_location(key) do
    GenServer.call(__MODULE__, {:get_data_location, key})
  end

  def optimize_placement do
    GenServer.cast(__MODULE__, :optimize_placement)
  end

  def get_placement_stats do
    GenServer.call(__MODULE__, :get_placement_stats)
  end

  def handle_memory_pressure(severity \\ :medium) do
    GenServer.cast(__MODULE__, {:handle_memory_pressure, severity})
  end

  # GenServer callbacks
  def init(opts) do
    state = %__MODULE__{
      local_node: node(),
      placement_strategies: initialize_strategies(),
      resource_monitor: initialize_resource_monitor(),
      access_patterns: %{},
      locality_cache: %{}
    }

    # Start periodic optimization
    schedule_optimization()
    
    {:ok, state}
  end

  def handle_call({:place_data, key, data, classification, opts}, _from, state) do
    # Get placement strategy from lifecycle manager
    {:ok, placement_strategy} = LifecycleManager.classify_data(key, classification)
    
    # Determine optimal storage tier and location
    storage_plan = create_storage_plan(key, data, placement_strategy, state)
    
    # Execute placement
    case execute_placement(storage_plan) do
      {:ok, locations} ->
        # Update access patterns
        new_state = update_access_patterns(key, locations, state)
        {:reply, {:ok, locations}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:relocate_data, key, new_classification}, _from, state) do
    case get_current_locations(key) do
      {:ok, current_locations} ->
        # Get new placement strategy
        {:ok, new_strategy} = LifecycleManager.classify_data(key, new_classification)
        
        # Create relocation plan
        relocation_plan = create_relocation_plan(key, current_locations, new_strategy)
        
        # Execute relocation
        case execute_relocation(relocation_plan) do
          {:ok, new_locations} ->
            new_state = update_access_patterns(key, new_locations, state)
            {:reply, {:ok, new_locations}, new_state}
          
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_data_location, key}, _from, state) do
    locations = Map.get(state.locality_cache, key, [])
    {:reply, {:ok, locations}, state}
  end

  def handle_call(:get_placement_stats, _from, state) do
    stats = %{
      local_placements: count_local_placements(state),
      remote_placements: count_remote_placements(state),
      cache_hit_ratio: calculate_cache_hit_ratio(state),
      memory_efficiency: calculate_memory_efficiency(state),
      access_patterns: get_access_pattern_summary(state)
    }
    {:reply, stats, state}
  end

  def handle_cast(:optimize_placement, state) do
    new_state = perform_optimization(state)
    {:noreply, new_state}
  end

  def handle_cast({:handle_memory_pressure, severity}, state) do
    new_state = handle_memory_pressure_internal(severity, state)
    {:noreply, new_state}
  end

  def handle_info(:periodic_optimization, state) do
    new_state = perform_periodic_optimization(state)
    schedule_optimization()
    {:noreply, new_state}
  end

  # Private implementation
  defp initialize_strategies do
    %{
      ephemeral: %{
        storage_tier: :ets_only,
        replication: :minimal,
        locality: :high
      },
      computational: %{
        storage_tier: :ets_primary_mnesia_backup,
        replication: :balanced,
        locality: :medium
      },
      session: %{
        storage_tier: :ets_only,
        replication: :none,
        locality: :very_high
      },
      persistent: %{
        storage_tier: :mnesia_primary_dets_backup,
        replication: :maximum,
        locality: :low
      }
    }
  end

  defp initialize_resource_monitor do
    %{
      memory_threshold: 0.8,  # 80% memory usage triggers optimization
      cpu_threshold: 0.7,     # 70% CPU usage
      network_latency: %{},   # Node-to-node latency measurements
      last_updated: System.system_time(:second)
    }
  end

  defp create_storage_plan(key, data, placement_strategy, state) do
    strategy = get_strategy_for_classification(placement_strategy, state)
    
    %{
      key: key,
      data: data,
      classification: placement_strategy,
      storage_tier: strategy.storage_tier,
      primary_node: placement_strategy.primary_node,
      replica_nodes: placement_strategy.replica_nodes,
      locality_preference: strategy.locality
    }
  end

  defp get_strategy_for_classification(placement_strategy, state) do
    # Extract classification from placement strategy metadata
    classification = Map.get(placement_strategy, :classification, :ephemeral)
    Map.get(state.placement_strategies, classification, state.placement_strategies.ephemeral)
  end

  defp execute_placement(storage_plan) do
    case storage_plan.storage_tier do
      :ets_only ->
        execute_ets_placement(storage_plan)
      
      :ets_primary_mnesia_backup ->
        execute_hybrid_placement(storage_plan, :ets, :mnesia)
      
      :mnesia_primary_dets_backup ->
        execute_hybrid_placement(storage_plan, :mnesia, :dets)
      
      _ ->
        {:error, :unsupported_storage_tier}
    end
  end

  defp execute_ets_placement(storage_plan) do
    # Place in local ETS if we're the primary node
    if storage_plan.primary_node == node() do
      case store_in_ets(storage_plan.key, storage_plan.data) do
        :ok ->
          locations = [%{node: node(), tier: :ets, role: :primary}]
          
          # Replicate to other nodes if needed
          replica_locations = replicate_to_nodes(storage_plan.replica_nodes, storage_plan.key, storage_plan.data, :ets)
          
          {:ok, locations ++ replica_locations}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      # Forward to primary node
      forward_to_primary(storage_plan)
    end
  end

  defp execute_hybrid_placement(storage_plan, primary_tier, backup_tier) do
    # Store in primary tier first
    case store_in_tier(storage_plan.key, storage_plan.data, primary_tier) do
      :ok ->
        locations = [%{node: node(), tier: primary_tier, role: :primary}]
        
        # Async backup to secondary tier
        Task.start(fn ->
          store_in_tier(storage_plan.key, storage_plan.data, backup_tier)
        end)
        
        backup_locations = [%{node: node(), tier: backup_tier, role: :backup}]
        
        # Replicate to other nodes
        replica_locations = replicate_to_nodes(storage_plan.replica_nodes, storage_plan.key, storage_plan.data, primary_tier)
        
        {:ok, locations ++ backup_locations ++ replica_locations}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_in_ets(key, data) do
    # Determine if it's a node or edge based on data structure
    case data do
      %{id: id, properties: properties} when not is_map_key(data, :from) ->
        # It's a node
        EtsGraphStore.create_node(properties)
      
      %{id: id, from: from_id, to: to_id, label: label, properties: properties} ->
        # It's an edge
        EtsGraphStore.create_edge(from_id, to_id, label, properties)
      
      %{} = generic_data ->
        # Generic data - just store successfully for now
        :ok
      
      _ ->
        # Fallback for simple data
        :ok
    end
  end

  defp store_in_tier(key, data, :ets), do: store_in_ets(key, data)
  defp store_in_tier(key, data, :mnesia), do: store_in_mnesia(key, data)
  defp store_in_tier(key, data, :dets), do: store_in_dets(key, data)

  defp store_in_mnesia(key, data) do
    # Simplified Mnesia storage - would need proper table schema
    :mnesia.transaction(fn ->
      :mnesia.write({:graph_data, key, data, System.system_time(:second)})
    end)
    |> case do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  defp store_in_dets(_key, _data) do
    # DETS implementation placeholder - minimal for now
    {:error, :dets_not_implemented}
  end

  defp replicate_to_nodes(replica_nodes, key, data, tier) do
    replica_nodes
    |> Enum.map(fn node ->
      case replicate_to_node(node, key, data, tier) do
        :ok -> %{node: node, tier: tier, role: :replica}
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp replicate_to_node(target_node, key, data, tier) do
    # For now, use simple GenServer call to remote node
    try do
      GenServer.call({__MODULE__, target_node}, {:store_replica, key, data, tier}, 5000)
    catch
      :exit, _ -> {:error, :node_unreachable}
    end
  end

  defp forward_to_primary(storage_plan) do
    try do
      GenServer.call({__MODULE__, storage_plan.primary_node}, {:execute_placement, storage_plan}, 10000)
    catch
      :exit, _ -> {:error, :primary_unreachable}
    end
  end

  defp create_relocation_plan(key, current_locations, new_strategy) do
    %{
      key: key,
      current_locations: current_locations,
      target_strategy: new_strategy,
      migration_steps: calculate_migration_steps(current_locations, new_strategy)
    }
  end

  defp execute_relocation(relocation_plan) do
    # Execute migration steps sequentially
    Enum.reduce_while(relocation_plan.migration_steps, {:ok, []}, fn step, {:ok, acc} ->
      case execute_migration_step(step) do
        {:ok, result} -> {:cont, {:ok, [result | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp calculate_migration_steps(_current_locations, _new_strategy) do
    # Simplified migration planning - would be more sophisticated in production
    [
      {:copy_to_new_location, :ets},
      {:verify_copy, :ets},
      {:cleanup_old_location, :ets}
    ]
  end

  defp execute_migration_step({:copy_to_new_location, tier}) do
    # Placeholder implementation
    {:ok, %{action: :copied, tier: tier}}
  end

  defp execute_migration_step({:verify_copy, tier}) do
    # Placeholder implementation
    {:ok, %{action: :verified, tier: tier}}
  end

  defp execute_migration_step({:cleanup_old_location, tier}) do
    # Placeholder implementation
    {:ok, %{action: :cleaned, tier: tier}}
  end

  defp get_current_locations(key) do
    # Query all storage tiers for the key
    locations = []
    
    # Check ETS
    locations = case EtsGraphStore.get_node(key) do
      {:ok, _} -> [%{node: node(), tier: :ets, role: :primary} | locations]
      {:error, :not_found} -> locations
    end
    
    {:ok, locations}
  end

  defp update_access_patterns(key, locations, state) do
    timestamp = System.system_time(:second)
    access_info = %{
      locations: locations,
      last_access: timestamp,
      access_count: get_access_count(key, state) + 1
    }
    
    new_patterns = Map.put(state.access_patterns, key, access_info)
    new_cache = Map.put(state.locality_cache, key, locations)
    
    %{state | access_patterns: new_patterns, locality_cache: new_cache}
  end

  defp get_access_count(key, state) do
    case Map.get(state.access_patterns, key) do
      nil -> 0
      access_info -> access_info.access_count
    end
  end

  defp perform_optimization(state) do
    # Identify optimization opportunities
    hot_data = identify_hot_data(state)
    cold_data = identify_cold_data(state)
    
    # Optimize hot data placement
    state = optimize_hot_data_placement(hot_data, state)
    
    # Move cold data to cheaper storage
    state = optimize_cold_data_placement(cold_data, state)
    
    state
  end

  defp perform_periodic_optimization(state) do
    # Update resource monitoring
    updated_state = update_resource_monitor(state)
    
    # Light optimization pass
    perform_optimization(updated_state)
  end

  defp handle_memory_pressure_internal(severity, state) do
    case severity do
      :low ->
        # Gentle cleanup
        evict_least_accessed_data(state, 0.1)
      
      :medium ->
        # More aggressive cleanup
        evict_least_accessed_data(state, 0.25)
      
      :high ->
        # Emergency cleanup
        evict_least_accessed_data(state, 0.5)
    end
  end

  defp identify_hot_data(state) do
    threshold = System.system_time(:second) - 300  # Last 5 minutes
    
    state.access_patterns
    |> Enum.filter(fn {_key, access_info} ->
      access_info.last_access > threshold and access_info.access_count > 5
    end)
    |> Enum.map(fn {key, _access_info} -> key end)
  end

  defp identify_cold_data(state) do
    threshold = System.system_time(:second) - 3600  # Last hour
    
    state.access_patterns
    |> Enum.filter(fn {_key, access_info} ->
      access_info.last_access < threshold
    end)
    |> Enum.map(fn {key, _access_info} -> key end)
  end

  defp optimize_hot_data_placement(hot_keys, state) do
    # Move hot data to faster storage tiers
    Enum.each(hot_keys, fn key ->
      relocate_data(key, :computational)
    end)
    
    state
  end

  defp optimize_cold_data_placement(cold_keys, state) do
    # Move cold data to slower/cheaper storage
    Enum.each(cold_keys, fn key ->
      relocate_data(key, :persistent)
    end)
    
    state
  end

  defp evict_least_accessed_data(state, percentage) do
    total_items = map_size(state.access_patterns)
    items_to_evict = round(total_items * percentage)
    
    candidates = state.access_patterns
    |> Enum.sort_by(fn {_key, access_info} -> access_info.last_access end)
    |> Enum.take(items_to_evict)
    |> Enum.map(fn {key, _access_info} -> key end)
    
    # Remove from access patterns and cache
    new_patterns = Enum.reduce(candidates, state.access_patterns, fn key, acc ->
      Map.delete(acc, key)
    end)
    
    new_cache = Enum.reduce(candidates, state.locality_cache, fn key, acc ->
      Map.delete(acc, key)
    end)
    
    %{state | access_patterns: new_patterns, locality_cache: new_cache}
  end

  defp count_local_placements(state) do
    local_node = state.local_node
    
    state.locality_cache
    |> Enum.count(fn {_key, locations} ->
      Enum.any?(locations, fn location -> location.node == local_node end)
    end)
  end

  defp count_remote_placements(state) do
    local_node = state.local_node
    
    state.locality_cache
    |> Enum.count(fn {_key, locations} ->
      Enum.all?(locations, fn location -> location.node != local_node end)
    end)
  end

  defp calculate_cache_hit_ratio(state) do
    total_accesses = state.access_patterns
    |> Enum.map(fn {_key, access_info} -> access_info.access_count end)
    |> Enum.sum()
    
    if total_accesses > 0 do
      local_accesses = count_local_placements(state)
      local_accesses / total_accesses
    else
      0.0
    end
  end

  defp calculate_memory_efficiency(state) do
    %{
      access_patterns_size: :erlang.external_size(state.access_patterns),
      locality_cache_size: :erlang.external_size(state.locality_cache),
      total_memory: :erlang.external_size(state)
    }
  end

  defp get_access_pattern_summary(state) do
    %{
      total_keys: map_size(state.access_patterns),
      avg_access_count: calculate_average_access_count(state),
      hot_keys: length(identify_hot_data(state)),
      cold_keys: length(identify_cold_data(state))
    }
  end

  defp calculate_average_access_count(state) do
    if map_size(state.access_patterns) > 0 do
      total_accesses = state.access_patterns
      |> Enum.map(fn {_key, access_info} -> access_info.access_count end)
      |> Enum.sum()
      
      total_accesses / map_size(state.access_patterns)
    else
      0.0
    end
  end

  defp update_resource_monitor(state) do
    current_time = System.system_time(:second)
    
    new_monitor = %{state.resource_monitor | 
      last_updated: current_time
    }
    
    %{state | resource_monitor: new_monitor}
  end

  defp schedule_optimization do
    Process.send_after(self(), :periodic_optimization, 60_000)  # Every minute
  end

  # Handle remote calls
  def handle_call({:store_replica, key, data, tier}, _from, state) do
    result = store_in_tier(key, data, tier)
    {:reply, result, state}
  end

  def handle_call({:execute_placement, storage_plan}, _from, state) do
    result = execute_placement(storage_plan)
    {:reply, result, state}
  end
end