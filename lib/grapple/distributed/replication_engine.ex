defmodule Grapple.Distributed.ReplicationEngine do
  @moduledoc """
  Smart replication strategies for distributed graph data.

  Handles:
  - Adaptive replication based on access patterns
  - Conflict resolution for concurrent updates
  - Eventual consistency with conflict-free replicated data types (CRDTs)
  - Intelligent replica placement and failover
  """

  use GenServer
  alias Grapple.Distributed.{LifecycleManager, ClusterManager, PlacementEngine}

  defstruct [
    :local_node,
    :replica_sets,
    :replication_policies,
    :conflict_resolver,
    :consistency_monitor,
    :vector_clocks
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def replicate_data(key, data, replication_policy \\ :adaptive) do
    GenServer.call(__MODULE__, {:replicate_data, key, data, replication_policy})
  end

  def update_replica(key, updates, node \\ node()) do
    GenServer.call(__MODULE__, {:update_replica, key, updates, node})
  end

  def resolve_conflicts(key) do
    GenServer.call(__MODULE__, {:resolve_conflicts, key})
  end

  def get_replica_health(key) do
    GenServer.call(__MODULE__, {:get_replica_health, key})
  end

  def promote_replica(key, target_node) do
    GenServer.call(__MODULE__, {:promote_replica, key, target_node})
  end

  def get_replication_stats do
    GenServer.call(__MODULE__, :get_replication_stats)
  end

  def handle_node_failure(failed_node) do
    GenServer.cast(__MODULE__, {:handle_node_failure, failed_node})
  end

  # GenServer callbacks
  def init(_opts) do
    state = %__MODULE__{
      local_node: node(),
      replica_sets: %{},
      replication_policies: initialize_replication_policies(),
      conflict_resolver: initialize_conflict_resolver(),
      consistency_monitor: initialize_consistency_monitor(),
      vector_clocks: %{}
    }

    # Start consistency monitoring
    schedule_consistency_check()

    {:ok, state}
  end

  def handle_call({:replicate_data, key, data, replication_policy}, _from, state) do
    # Determine replication strategy
    strategy = get_replication_strategy(replication_policy, key, data, state)

    # Create replica set
    {:ok, replica_set, new_state} = create_replica_set(key, data, strategy, state)
    {:reply, {:ok, replica_set}, new_state}
  end

  def handle_call({:update_replica, key, updates, source_node}, _from, state) do
    case get_replica_set(key, state) do
      {:ok, replica_set} ->
        # Create vector clock entry for this update
        vector_clock = advance_vector_clock(key, source_node, state)

        # Apply update with conflict detection
        case apply_update_with_conflicts(key, updates, vector_clock, replica_set, state) do
          {:ok, _new_replica_set, new_state} ->
            {:reply, {:ok, :updated}, new_state}

          {:conflict, conflict_info, new_state} ->
            {:reply, {:conflict, conflict_info}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:resolve_conflicts, key}, _from, state) do
    {:ok, replica_set} = get_replica_set(key, state)
    {:ok, resolved_data, new_state} = resolve_replica_conflicts(replica_set, state)
    {:reply, {:ok, resolved_data}, new_state}
  end

  def handle_call({:get_replica_health, key}, _from, state) do
    case get_replica_set(key, state) do
      {:ok, replica_set} ->
        health = calculate_replica_health(replica_set)
        {:reply, {:ok, health}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:promote_replica, key, target_node}, _from, state) do
    case promote_replica_to_primary(key, target_node, state) do
      {:ok, new_state} ->
        {:reply, {:ok, :promoted}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_replication_stats, _from, state) do
    stats = %{
      total_replica_sets: map_size(state.replica_sets),
      consistency_level: calculate_overall_consistency(state),
      replication_efficiency: calculate_replication_efficiency(state),
      conflict_rate: calculate_conflict_rate(state),
      failover_events: count_failover_events(state)
    }

    {:reply, stats, state}
  end

  # Handle remote replication calls
  def handle_call({:store_replica, key, data, strategy}, _from, state) do
    # Store as replica on this node
    replica = %{
      node: node(),
      data: data,
      version: 1,
      vector_clock: %{node() => 1},
      last_updated: System.system_time(:second),
      status: :replica,
      conflicts: []
    }

    # Create or update replica set
    replica_set =
      case Map.get(state.replica_sets, key) do
        nil ->
          %{
            primary: node(),
            replicas: [replica],
            strategy: strategy,
            last_sync: System.system_time(:second)
          }

        existing ->
          %{
            existing
            | replicas: [replica | existing.replicas],
              last_sync: System.system_time(:second)
          }
      end

    new_replica_sets = Map.put(state.replica_sets, key, replica_set)
    new_state = %{state | replica_sets: new_replica_sets}

    {:reply, :ok, new_state}
  end

  def handle_cast({:handle_node_failure, failed_node}, state) do
    new_state = handle_node_failure_internal(failed_node, state)
    {:noreply, new_state}
  end

  def handle_info(:consistency_check, state) do
    new_state = perform_consistency_check(state)
    schedule_consistency_check()
    {:noreply, new_state}
  end

  # Private implementation
  defp initialize_replication_policies do
    %{
      minimal: %{
        min_replicas: 1,
        max_replicas: 2,
        consistency: :eventual,
        conflict_resolution: :last_write_wins
      },
      balanced: %{
        min_replicas: 2,
        max_replicas: 3,
        consistency: :strong_eventual,
        conflict_resolution: :vector_clock
      },
      maximum: %{
        min_replicas: 3,
        max_replicas: 5,
        consistency: :strong,
        conflict_resolution: :consensus
      },
      adaptive: %{
        min_replicas: 1,
        max_replicas: :auto,
        consistency: :adaptive,
        conflict_resolution: :smart
      }
    }
  end

  defp initialize_conflict_resolver do
    %{
      strategies: [:last_write_wins, :vector_clock, :consensus, :semantic_merge],
      active_conflicts: %{},
      resolution_history: []
    }
  end

  defp initialize_consistency_monitor do
    %{
      # 30 seconds
      check_interval: 30_000,
      inconsistencies: %{},
      repair_queue: [],
      last_check: System.system_time(:second)
    }
  end

  defp get_replication_strategy(replication_policy, key, data, state) do
    base_policy =
      Map.get(state.replication_policies, replication_policy, state.replication_policies.balanced)

    # Adapt based on data characteristics and access patterns
    case replication_policy do
      :adaptive ->
        adapt_replication_strategy(key, data, base_policy, state)

      _ ->
        base_policy
    end
  end

  defp adapt_replication_strategy(key, data, base_policy, state) do
    # Get access patterns if available
    access_frequency = get_access_frequency(key, state)
    data_size = :erlang.external_size(data)
    cluster_size = length(ClusterManager.get_cluster_info().nodes)

    # Adaptive logic
    adapted_replicas =
      cond do
        access_frequency > 100 and data_size < 10_000 ->
          # High access, small data: replicate widely
          min(cluster_size, 4)

        access_frequency > 50 ->
          # Medium access: balanced replication
          min(cluster_size, 3)

        data_size > 100_000 ->
          # Large data: minimal replication
          2

        true ->
          # Default: balanced
          min(cluster_size, 2)
      end

    %{base_policy | min_replicas: adapted_replicas, max_replicas: adapted_replicas}
  end

  defp create_replica_set(key, data, strategy, state) do
    # Get target nodes from cluster manager or use current node if lifecycle not available
    target_nodes =
      case LifecycleManager.get_replication_nodes(key, strategy.max_replicas) do
        {:ok, nodes} ->
          nodes

        {:error, :key_not_classified} ->
          # Fallback: classify the key first, then get nodes
          LifecycleManager.classify_data(key, :ephemeral)

          case LifecycleManager.get_replication_nodes(key, strategy.max_replicas) do
            {:ok, nodes} -> nodes
            # Ultimate fallback: use current node
            _ -> [node()]
          end

        _ ->
          [node()]
      end

    # Create replica entries
    replicas =
      Enum.map(target_nodes, fn node ->
        %{
          node: node,
          data: data,
          version: 1,
          vector_clock: %{node => 1},
          last_updated: System.system_time(:second),
          status: if(node == node(), do: :primary, else: :replica),
          conflicts: []
        }
      end)

    replica_set = %{
      key: key,
      strategy: strategy,
      replicas: replicas,
      primary_node: hd(target_nodes),
      created_at: System.system_time(:second),
      last_sync: System.system_time(:second)
    }

    # Store replica set
    new_replica_sets = Map.put(state.replica_sets, key, replica_set)
    new_state = %{state | replica_sets: new_replica_sets}

    # Initiate replication to remote nodes
    Task.start(fn ->
      replicate_to_remote_nodes(key, data, target_nodes, strategy)
    end)

    {:ok, replica_set, new_state}
  end

  defp replicate_to_remote_nodes(key, data, target_nodes, strategy) do
    remote_nodes = List.delete(target_nodes, node())

    Enum.each(remote_nodes, fn target_node ->
      try do
        GenServer.call({__MODULE__, target_node}, {:store_replica, key, data, strategy}, 5000)
      catch
        :exit, _ ->
          # Log replication failure
          :ok
      end
    end)
  end

  defp get_replica_set(key, state) do
    case Map.get(state.replica_sets, key) do
      nil -> {:error, :replica_set_not_found}
      replica_set -> {:ok, replica_set}
    end
  end

  defp apply_update_with_conflicts(key, updates, vector_clock, replica_set, state) do
    # Find the local replica
    case find_local_replica(replica_set) do
      {:ok, local_replica} ->
        # Check for conflicts using vector clocks
        case detect_conflicts(vector_clock, local_replica.vector_clock) do
          :no_conflict ->
            # Apply update
            updated_replica = apply_update_to_replica(local_replica, updates, vector_clock)
            updated_replica_set = update_replica_in_set(replica_set, updated_replica)

            new_state = update_replica_set(key, updated_replica_set, state)

            # Propagate update to other replicas
            propagate_update(key, updates, vector_clock, replica_set)

            {:ok, updated_replica_set, new_state}

          {:conflict, conflict_type} ->
            # Record conflict for resolution
            conflict_info = %{
              type: conflict_type,
              local_vector: local_replica.vector_clock,
              update_vector: vector_clock,
              timestamp: System.system_time(:second)
            }

            {:conflict, conflict_info, state}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp advance_vector_clock(key, source_node, state) do
    current_clock = Map.get(state.vector_clocks, key, %{})
    current_value = Map.get(current_clock, source_node, 0)
    new_clock = Map.put(current_clock, source_node, current_value + 1)

    # Update state
    new_vector_clocks = Map.put(state.vector_clocks, key, new_clock)
    %{state | vector_clocks: new_vector_clocks}

    new_clock
  end

  defp detect_conflicts(vector_clock_a, vector_clock_b) do
    # Vector clock comparison for conflict detection
    keys =
      MapSet.union(
        MapSet.new(Map.keys(vector_clock_a)),
        MapSet.new(Map.keys(vector_clock_b))
      )

    comparison_results =
      Enum.map(keys, fn key ->
        val_a = Map.get(vector_clock_a, key, 0)
        val_b = Map.get(vector_clock_b, key, 0)

        cond do
          val_a > val_b -> :greater
          val_a < val_b -> :less
          true -> :equal
        end
      end)

    case {Enum.member?(comparison_results, :greater), Enum.member?(comparison_results, :less)} do
      # A > B
      {true, false} -> :no_conflict
      # B > A
      {false, true} -> :no_conflict
      # A = B
      {false, false} -> :no_conflict
      {true, true} -> {:conflict, :concurrent_updates}
    end
  end

  defp find_local_replica(replica_set) do
    local_node = node()

    case Enum.find(replica_set.replicas, fn replica ->
           replica.node == local_node
         end) do
      nil -> {:error, :local_replica_not_found}
      replica -> {:ok, replica}
    end
  end

  defp apply_update_to_replica(replica, updates, vector_clock) do
    # Apply updates to replica data
    updated_data = merge_updates(replica.data, updates)

    %{
      replica
      | data: updated_data,
        version: replica.version + 1,
        vector_clock: vector_clock,
        last_updated: System.system_time(:second)
    }
  end

  defp merge_updates(current_data, updates) do
    # Simple merge strategy - can be enhanced based on data type
    case {current_data, updates} do
      {%{} = map_data, %{} = map_updates} ->
        Map.merge(map_data, map_updates)

      _ ->
        # For non-map data, replace entirely
        updates
    end
  end

  defp update_replica_in_set(replica_set, updated_replica) do
    updated_replicas =
      Enum.map(replica_set.replicas, fn replica ->
        if replica.node == updated_replica.node do
          updated_replica
        else
          replica
        end
      end)

    %{replica_set | replicas: updated_replicas, last_sync: System.system_time(:second)}
  end

  defp update_replica_set(key, updated_replica_set, state) do
    new_replica_sets = Map.put(state.replica_sets, key, updated_replica_set)
    %{state | replica_sets: new_replica_sets}
  end

  defp propagate_update(key, updates, _vector_clock, replica_set) do
    # Async propagation to other replicas
    Task.start(fn ->
      remote_nodes =
        replica_set.replicas
        |> Enum.map(& &1.node)
        |> List.delete(node())

      Enum.each(remote_nodes, fn target_node ->
        try do
          GenServer.call({__MODULE__, target_node}, {:update_replica, key, updates, node()}, 5000)
        catch
          :exit, _ -> :ok
        end
      end)
    end)
  end

  defp resolve_replica_conflicts(replica_set, state) do
    # Get all conflicted replicas
    conflicted_replicas =
      Enum.filter(replica_set.replicas, fn replica ->
        length(replica.conflicts) > 0
      end)

    case conflicted_replicas do
      [] ->
        # No conflicts to resolve
        {:ok, get_latest_data(replica_set), state}

      conflicts ->
        # Apply conflict resolution strategy
        case replica_set.strategy.conflict_resolution do
          :last_write_wins ->
            resolve_by_last_write_wins(conflicts, state)

          :vector_clock ->
            resolve_by_vector_clock(conflicts, state)

          :consensus ->
            resolve_by_consensus(conflicts, state)

          :smart ->
            resolve_by_smart_merge(conflicts, state)
        end
    end
  end

  defp resolve_by_last_write_wins(conflicted_replicas, state) do
    # Find replica with latest timestamp
    latest_replica = Enum.max_by(conflicted_replicas, & &1.last_updated)
    {:ok, latest_replica.data, state}
  end

  defp resolve_by_vector_clock(conflicted_replicas, state) do
    # Use vector clock causality to resolve
    # For now, fall back to last write wins
    resolve_by_last_write_wins(conflicted_replicas, state)
  end

  defp resolve_by_consensus(conflicted_replicas, state) do
    # Simple majority consensus
    data_versions = Enum.map(conflicted_replicas, & &1.data)
    data_counts = Enum.frequencies(data_versions)

    case Enum.max_by(data_counts, fn {_data, count} -> count end) do
      {winning_data, _count} ->
        {:ok, winning_data, state}
    end
  end

  defp resolve_by_smart_merge(conflicted_replicas, state) do
    # Intelligent semantic merge based on data type
    case detect_data_type(conflicted_replicas) do
      :graph_node ->
        resolve_graph_node_conflicts(conflicted_replicas, state)

      :graph_edge ->
        resolve_graph_edge_conflicts(conflicted_replicas, state)

      _ ->
        # Fall back to last write wins
        resolve_by_last_write_wins(conflicted_replicas, state)
    end
  end

  defp detect_data_type(replicas) do
    case hd(replicas).data do
      %{id: _, properties: _} -> :graph_node
      %{from: _, to: _, label: _} -> :graph_edge
      _ -> :unknown
    end
  end

  defp resolve_graph_node_conflicts(conflicted_replicas, state) do
    # Merge properties from all replicas
    merged_properties =
      conflicted_replicas
      |> Enum.map(& &1.data.properties)
      |> Enum.reduce(%{}, fn props, acc -> Map.merge(acc, props) end)

    base_data = hd(conflicted_replicas).data
    resolved_data = %{base_data | properties: merged_properties}

    {:ok, resolved_data, state}
  end

  defp resolve_graph_edge_conflicts(conflicted_replicas, state) do
    # For edges, properties can be merged, but from/to/label must be consistent
    base_replica = hd(conflicted_replicas)

    # Verify structural consistency
    structural_consistent =
      Enum.all?(conflicted_replicas, fn replica ->
        base_replica.data.from == replica.data.from and
          base_replica.data.to == replica.data.to and
          base_replica.data.label == replica.data.label
      end)

    if structural_consistent do
      # Merge properties
      merged_properties =
        conflicted_replicas
        |> Enum.map(& &1.data.properties)
        |> Enum.reduce(%{}, fn props, acc -> Map.merge(acc, props) end)

      resolved_data = %{base_replica.data | properties: merged_properties}
      {:ok, resolved_data, state}
    else
      # Structural conflict - use last write wins
      resolve_by_last_write_wins(conflicted_replicas, state)
    end
  end

  defp get_latest_data(replica_set) do
    replica_set.replicas
    |> Enum.max_by(& &1.last_updated)
    |> Map.get(:data)
  end

  defp promote_replica_to_primary(key, target_node, state) do
    case get_replica_set(key, state) do
      {:ok, replica_set} ->
        # Update primary designation
        updated_replicas =
          Enum.map(replica_set.replicas, fn replica ->
            cond do
              replica.node == target_node ->
                %{replica | status: :primary}

              replica.status == :primary ->
                %{replica | status: :replica}

              true ->
                replica
            end
          end)

        updated_replica_set = %{
          replica_set
          | primary_node: target_node,
            replicas: updated_replicas
        }

        new_state = update_replica_set(key, updated_replica_set, state)
        {:ok, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_node_failure_internal(failed_node, state) do
    # Find all replica sets affected by the failure
    affected_sets =
      state.replica_sets
      |> Enum.filter(fn {_key, replica_set} ->
        Enum.any?(replica_set.replicas, &(&1.node == failed_node))
      end)

    # Process each affected set
    Enum.reduce(affected_sets, state, fn {key, replica_set}, acc_state ->
      handle_replica_set_failure(key, replica_set, failed_node, acc_state)
    end)
  end

  defp handle_replica_set_failure(key, replica_set, failed_node, state) do
    # Remove failed replica
    surviving_replicas = Enum.filter(replica_set.replicas, &(&1.node != failed_node))

    # Promote new primary if needed
    {new_primary, updated_replicas} =
      if replica_set.primary_node == failed_node do
        case surviving_replicas do
          [] ->
            # No surviving replicas - mark as unavailable
            {nil, []}

          [first_replica | rest] ->
            # Promote first surviving replica to primary
            promoted = %{first_replica | status: :primary}
            {promoted.node, [promoted | rest]}
        end
      else
        {replica_set.primary_node, surviving_replicas}
      end

    # Create replacement replicas if needed
    target_replica_count = replica_set.strategy.min_replicas
    current_count = length(updated_replicas)

    final_replicas =
      if current_count < target_replica_count and new_primary != nil do
        # Need to create new replicas
        cluster_nodes = ClusterManager.get_cluster_info().nodes
        available_nodes = cluster_nodes -- Enum.map(updated_replicas, & &1.node)

        needed_replicas = min(target_replica_count - current_count, length(available_nodes))

        new_replicas =
          available_nodes
          |> Enum.take(needed_replicas)
          |> Enum.map(fn node ->
            %{
              node: node,
              data: get_latest_data(replica_set),
              version: 1,
              vector_clock: %{node => 1},
              last_updated: System.system_time(:second),
              status: :replica,
              conflicts: []
            }
          end)

        updated_replicas ++ new_replicas
      else
        updated_replicas
      end

    updated_replica_set = %{
      replica_set
      | primary_node: new_primary,
        replicas: final_replicas,
        last_sync: System.system_time(:second)
    }

    update_replica_set(key, updated_replica_set, state)
  end

  defp calculate_replica_health(replica_set) do
    total_replicas = length(replica_set.replicas)

    healthy_replicas =
      Enum.count(replica_set.replicas, fn replica ->
        # Consider healthy if updated recently
        # 5 minutes
        System.system_time(:second) - replica.last_updated < 300
      end)

    health_ratio = if total_replicas > 0, do: healthy_replicas / total_replicas, else: 0.0

    %{
      total_replicas: total_replicas,
      healthy_replicas: healthy_replicas,
      health_ratio: health_ratio,
      primary_healthy: replica_set.primary_node != nil,
      last_sync: replica_set.last_sync,
      conflicts: count_total_conflicts(replica_set)
    }
  end

  defp count_total_conflicts(replica_set) do
    replica_set.replicas
    |> Enum.map(&length(&1.conflicts))
    |> Enum.sum()
  end

  defp perform_consistency_check(state) do
    # Check each replica set for consistency issues
    issues =
      state.replica_sets
      |> Enum.flat_map(fn {key, replica_set} ->
        check_replica_set_consistency(key, replica_set)
      end)

    # Update consistency monitor
    new_monitor = %{
      state.consistency_monitor
      | inconsistencies: Enum.into(issues, %{}),
        last_check: System.system_time(:second)
    }

    %{state | consistency_monitor: new_monitor}
  end

  defp check_replica_set_consistency(key, replica_set) do
    # Compare data across replicas
    data_versions =
      Enum.map(replica_set.replicas, fn replica ->
        {replica.node, replica.data, replica.vector_clock}
      end)

    # Find inconsistencies
    case Enum.uniq_by(data_versions, fn {_node, data, _clock} -> data end) do
      [_single_version] ->
        # All replicas have same data
        []

      multiple_versions ->
        # Inconsistency detected
        [
          {key,
           %{
             type: :data_divergence,
             versions: multiple_versions,
             detected_at: System.system_time(:second)
           }}
        ]
    end
  end

  defp get_access_frequency(key, _state) do
    # Try to get access patterns from placement engine
    try do
      case GenServer.call(PlacementEngine, {:get_access_count, key}, 1000) do
        {:ok, count} -> count
        _ -> 0
      end
    catch
      :exit, _ -> 0
    end
  end

  defp calculate_overall_consistency(state) do
    total_sets = map_size(state.replica_sets)
    inconsistent_sets = map_size(state.consistency_monitor.inconsistencies)

    if total_sets > 0 do
      (total_sets - inconsistent_sets) / total_sets
    else
      1.0
    end
  end

  defp calculate_replication_efficiency(state) do
    # Average replica health across all sets
    health_ratios =
      state.replica_sets
      |> Enum.map(fn {_key, replica_set} ->
        health = calculate_replica_health(replica_set)
        health.health_ratio
      end)

    if length(health_ratios) > 0 do
      Enum.sum(health_ratios) / length(health_ratios)
    else
      1.0
    end
  end

  defp calculate_conflict_rate(state) do
    total_conflicts =
      state.replica_sets
      |> Enum.map(fn {_key, replica_set} -> count_total_conflicts(replica_set) end)
      |> Enum.sum()

    total_replicas =
      state.replica_sets
      |> Enum.map(fn {_key, replica_set} -> length(replica_set.replicas) end)
      |> Enum.sum()

    if total_replicas > 0 do
      total_conflicts / total_replicas
    else
      0.0
    end
  end

  defp count_failover_events(state) do
    # Count replica sets where primary changed recently
    # Last hour
    recent_threshold = System.system_time(:second) - 3600

    state.replica_sets
    |> Enum.count(fn {_key, replica_set} ->
      replica_set.last_sync > recent_threshold
    end)
  end

  defp schedule_consistency_check do
    # Every 30 seconds
    Process.send_after(self(), :consistency_check, 30_000)
  end
end
