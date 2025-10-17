defmodule Grapple.Distributed.PersistenceManager do
  @moduledoc """
  Dynamic persistence policy management for adaptive data storage.

  Manages:
  - Automatic policy adaptation based on usage patterns
  - Hot/cold data classification and migration
  - Storage tier optimization (ETS -> Mnesia -> DETS)
  - Cost-aware persistence decisions
  """

  use GenServer
  alias Grapple.Storage.EtsGraphStore

  @storage_tiers [:ets, :mnesia, :dets]
  @tier_characteristics %{
    ets: %{speed: :fastest, cost: :highest, durability: :none, capacity: :limited},
    mnesia: %{speed: :fast, cost: :medium, durability: :high, capacity: :medium},
    dets: %{speed: :slow, cost: :lowest, durability: :highest, capacity: :large}
  }

  defstruct [
    :local_node,
    :persistence_policies,
    :tier_utilization,
    :cost_models,
    :migration_queue,
    :policy_adaptations
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API
  def create_persistence_policy(name, policy_config) do
    GenServer.call(__MODULE__, {:create_policy, name, policy_config})
  end

  def apply_persistence_policy(data_key, policy_name) do
    GenServer.call(__MODULE__, {:apply_policy, data_key, policy_name})
  end

  def adapt_policy_for_data(data_key, usage_patterns) do
    GenServer.call(__MODULE__, {:adapt_policy, data_key, usage_patterns})
  end

  def migrate_to_tier(data_key, target_tier, reason \\ :optimization) do
    GenServer.call(__MODULE__, {:migrate_to_tier, data_key, target_tier, reason})
  end

  def get_optimal_tier(data_characteristics) do
    GenServer.call(__MODULE__, {:get_optimal_tier, data_characteristics})
  end

  def get_persistence_stats do
    GenServer.call(__MODULE__, :get_persistence_stats)
  end

  def optimize_storage_allocation do
    GenServer.cast(__MODULE__, :optimize_storage)
  end

  def handle_memory_pressure(severity) do
    GenServer.cast(__MODULE__, {:handle_memory_pressure, severity})
  end

  # GenServer callbacks
  def init(_opts) do
    state = %__MODULE__{
      local_node: node(),
      persistence_policies: initialize_default_policies(),
      tier_utilization: initialize_tier_monitoring(),
      cost_models: initialize_cost_models(),
      migration_queue: :queue.new(),
      policy_adaptations: %{}
    }

    # Start periodic optimization
    schedule_optimization()
    schedule_tier_monitoring()

    {:ok, state}
  end

  def handle_call({:create_policy, name, policy_config}, _from, state) do
    case validate_policy_config(policy_config) do
      :ok ->
        new_policies = Map.put(state.persistence_policies, name, policy_config)
        new_state = %{state | persistence_policies: new_policies}
        {:reply, {:ok, :policy_created}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_policy, data_key, policy_name}, _from, state) do
    case Map.get(state.persistence_policies, policy_name) do
      nil ->
        {:reply, {:error, :policy_not_found}, state}

      policy ->
        case apply_persistence_policy_internal(data_key, policy, state) do
          {:ok, placement_result, new_state} ->
            {:reply, {:ok, placement_result}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:adapt_policy, data_key, usage_patterns}, _from, state) do
    {:ok, adapted_policy, new_state} = create_adaptive_policy(data_key, usage_patterns, state)

    case apply_persistence_policy_internal(data_key, adapted_policy, new_state) do
      {:ok, placement_result, final_state} ->
        {:reply, {:ok, {adapted_policy, placement_result}}, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:migrate_to_tier, data_key, target_tier, reason}, _from, state) do
    case execute_tier_migration(data_key, target_tier, reason, state) do
      {:ok, migration_result, new_state} ->
        {:reply, {:ok, migration_result}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_optimal_tier, data_characteristics}, _from, state) do
    optimal_tier = calculate_optimal_tier(data_characteristics, state)
    {:reply, optimal_tier, state}
  end

  def handle_call(:get_persistence_stats, _from, state) do
    stats = %{
      active_policies: map_size(state.persistence_policies),
      tier_utilization: state.tier_utilization,
      migration_queue_size: :queue.len(state.migration_queue),
      policy_adaptations: map_size(state.policy_adaptations),
      cost_efficiency: calculate_cost_efficiency(state)
    }

    {:reply, stats, state}
  end

  def handle_cast(:optimize_storage, state) do
    new_state = perform_storage_optimization(state)
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

  def handle_info(:tier_monitoring, state) do
    new_state = update_tier_monitoring(state)
    schedule_tier_monitoring()
    {:noreply, new_state}
  end

  def handle_info(:process_migration_queue, state) do
    new_state = process_migration_queue(state)
    schedule_migration_processing()
    {:noreply, new_state}
  end

  # Private implementation
  defp initialize_default_policies do
    %{
      hot_data: %{
        primary_tier: :ets,
        backup_tier: :mnesia,
        replication_factor: 2,
        # accesses per hour
        access_threshold: 50,
        migration_triggers: [:high_access, :low_latency_required],
        retention_policy: :keep_until_cold
      },
      warm_data: %{
        primary_tier: :mnesia,
        backup_tier: :dets,
        replication_factor: 2,
        access_threshold: 10,
        migration_triggers: [:medium_access, :balanced_performance],
        retention_policy: :migrate_when_cold
      },
      cold_data: %{
        primary_tier: :dets,
        backup_tier: nil,
        replication_factor: 1,
        access_threshold: 1,
        migration_triggers: [:low_access, :cost_optimization],
        retention_policy: :archive_or_delete
      },
      ephemeral_compute: %{
        primary_tier: :ets,
        backup_tier: nil,
        replication_factor: 1,
        access_threshold: :unlimited,
        migration_triggers: [:computation_complete, :memory_pressure],
        retention_policy: :delete_on_complete
      },
      critical_persistent: %{
        primary_tier: :mnesia,
        backup_tier: :dets,
        replication_factor: 3,
        access_threshold: :any,
        migration_triggers: [:never],
        retention_policy: :permanent
      }
    }
  end

  defp initialize_tier_monitoring do
    %{
      ets: %{
        memory_used: 0,
        memory_limit: get_ets_memory_limit(),
        item_count: 0,
        access_rate: 0.0,
        last_updated: System.system_time(:second)
      },
      mnesia: %{
        memory_used: 0,
        memory_limit: get_mnesia_memory_limit(),
        item_count: 0,
        access_rate: 0.0,
        last_updated: System.system_time(:second)
      },
      dets: %{
        disk_used: 0,
        disk_limit: get_dets_disk_limit(),
        item_count: 0,
        access_rate: 0.0,
        last_updated: System.system_time(:second)
      }
    }
  end

  defp initialize_cost_models do
    %{
      ets: %{
        # Arbitrary cost units
        memory_cost_per_mb: 10.0,
        access_cost: 0.001,
        maintenance_cost: 5.0
      },
      mnesia: %{
        memory_cost_per_mb: 3.0,
        disk_cost_per_mb: 1.0,
        access_cost: 0.01,
        maintenance_cost: 2.0
      },
      dets: %{
        disk_cost_per_mb: 0.1,
        access_cost: 0.1,
        maintenance_cost: 1.0
      }
    }
  end

  defp validate_policy_config(policy_config) do
    required_fields = [:primary_tier, :replication_factor, :retention_policy]

    case Enum.all?(required_fields, &Map.has_key?(policy_config, &1)) do
      true ->
        case Map.get(policy_config, :primary_tier) in @storage_tiers do
          true -> :ok
          false -> {:error, :invalid_storage_tier}
        end

      false ->
        {:error, :missing_required_fields}
    end
  end

  defp apply_persistence_policy_internal(data_key, policy, state) do
    # Determine current data characteristics
    _data_characteristics = analyze_data_characteristics(data_key)

    # Calculate optimal tier based on policy and characteristics
    target_tier = policy.primary_tier

    # Check if data needs to be moved to target tier
    current_tier = get_current_storage_tier(data_key)

    if current_tier != target_tier do
      case execute_tier_migration(data_key, target_tier, :policy_application, state) do
        {:ok, migration_result, new_state} ->
          {:ok, migration_result, new_state}

        {:error, reason} ->
          {:error, reason}
      end
    else
      # Already in correct tier
      {:ok, %{tier: current_tier, action: :no_migration_needed}, state}
    end
  end

  defp create_adaptive_policy(data_key, usage_patterns, state) do
    # Analyze usage patterns to create optimal policy
    access_frequency = Map.get(usage_patterns, :access_frequency, 0)
    data_size = Map.get(usage_patterns, :data_size, 0)
    access_pattern = Map.get(usage_patterns, :access_pattern, :random)
    retention_requirement = Map.get(usage_patterns, :retention_requirement, :standard)

    # Determine classification
    classification = classify_data_by_patterns(access_frequency, data_size, access_pattern)

    # Create adaptive policy
    adapted_policy =
      case classification do
        :hot ->
          %{
            primary_tier: :ets,
            backup_tier: if(retention_requirement == :critical, do: :mnesia, else: nil),
            replication_factor: if(retention_requirement == :critical, do: 3, else: 2),
            access_threshold: access_frequency,
            migration_triggers: [:memory_pressure],
            retention_policy:
              if(retention_requirement == :critical, do: :permanent, else: :keep_until_cold)
          }

        :warm ->
          %{
            primary_tier: :mnesia,
            backup_tier: if(retention_requirement == :critical, do: :dets, else: nil),
            replication_factor: 2,
            access_threshold: max(access_frequency, 5),
            migration_triggers: [:cost_optimization, :low_access],
            retention_policy: :migrate_when_cold
          }

        :cold ->
          %{
            primary_tier: :dets,
            backup_tier: nil,
            replication_factor: 1,
            access_threshold: 1,
            migration_triggers: [:almost_never],
            retention_policy:
              if(retention_requirement == :critical, do: :permanent, else: :archive_or_delete)
          }
      end

    # Store adaptation for future reference
    new_adaptations =
      Map.put(state.policy_adaptations, data_key, {adapted_policy, System.system_time(:second)})

    new_state = %{state | policy_adaptations: new_adaptations}

    {:ok, adapted_policy, new_state}
  end

  defp classify_data_by_patterns(access_frequency, data_size, _access_pattern) do
    cond do
      access_frequency > 100 and data_size < 100_000 -> :hot
      access_frequency > 10 and data_size < 1_000_000 -> :warm
      true -> :cold
    end
  end

  defp execute_tier_migration(data_key, target_tier, reason, state) do
    # Get current data
    case get_data_from_current_tier(data_key) do
      {:ok, data, current_tier} ->
        # Store in target tier
        case store_data_in_tier(data_key, data, target_tier) do
          :ok ->
            # Remove from current tier if different
            if current_tier != target_tier do
              remove_data_from_tier(data_key, current_tier)
            end

            # Update monitoring
            new_state =
              update_tier_utilization_after_migration(
                data_key,
                data,
                current_tier,
                target_tier,
                state
              )

            migration_result = %{
              data_key: data_key,
              from_tier: current_tier,
              to_tier: target_tier,
              reason: reason,
              timestamp: System.system_time(:second)
            }

            {:ok, migration_result, new_state}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_optimal_tier(data_characteristics, state) do
    access_frequency = Map.get(data_characteristics, :access_frequency, 0)
    data_size = Map.get(data_characteristics, :data_size, 0)
    latency_requirement = Map.get(data_characteristics, :latency_requirement, :standard)
    durability_requirement = Map.get(data_characteristics, :durability_requirement, :standard)

    # Calculate scores for each tier
    tier_scores =
      Enum.map(@storage_tiers, fn tier ->
        tier_info = Map.get(@tier_characteristics, tier)
        cost_model = Map.get(state.cost_models, tier)
        utilization = Map.get(state.tier_utilization, tier)

        score =
          calculate_tier_score(
            tier_info,
            cost_model,
            utilization,
            access_frequency,
            data_size,
            latency_requirement,
            durability_requirement
          )

        {tier, score}
      end)

    # Return tier with highest score
    {optimal_tier, _score} = Enum.max_by(tier_scores, fn {_tier, score} -> score end)
    {:ok, optimal_tier}
  end

  defp calculate_tier_score(
         tier_info,
         cost_model,
         utilization,
         access_freq,
         data_size,
         latency_req,
         durability_req
       ) do
    # Performance score
    performance_score =
      case {tier_info.speed, latency_req} do
        {:fastest, :low} -> 100
        {:fastest, :standard} -> 90
        {:fast, :low} -> 70
        {:fast, :standard} -> 90
        {:slow, :low} -> 30
        {:slow, :standard} -> 60
        _ -> 50
      end

    # Cost efficiency score
    memory_cost = data_size / 1_048_576 * Map.get(cost_model, :memory_cost_per_mb, 0)
    access_cost = access_freq * Map.get(cost_model, :access_cost, 0)
    total_cost = memory_cost + access_cost + Map.get(cost_model, :maintenance_cost, 0)

    cost_score = max(0, 100 - total_cost)

    # Utilization penalty
    utilization_ratio =
      case Map.get(utilization, :memory_used, 0) do
        0 -> 0.0
        used -> used / max(Map.get(utilization, :memory_limit, 1), 1)
      end

    # Penalty for high utilization
    utilization_penalty = utilization_ratio * 50

    # Durability score
    durability_score =
      case {tier_info.durability, durability_req} do
        {:highest, :critical} -> 100
        {:high, :critical} -> 80
        {:none, :critical} -> 20
        {:highest, :standard} -> 90
        {:high, :standard} -> 100
        {:none, :standard} -> 70
        _ -> 50
      end

    # Combined weighted score
    performance_score * 0.3 + cost_score * 0.3 + durability_score * 0.2 +
      (100 - utilization_penalty) * 0.2
  end

  defp perform_storage_optimization(state) do
    # Identify optimization opportunities
    optimization_candidates = identify_optimization_candidates(state)

    # Process optimization candidates
    Enum.reduce(optimization_candidates, state, fn {data_key, recommended_tier, reason},
                                                   acc_state ->
      case execute_tier_migration(data_key, recommended_tier, reason, acc_state) do
        {:ok, _migration_result, new_state} -> new_state
        {:error, _reason} -> acc_state
      end
    end)
  end

  defp identify_optimization_candidates(state) do
    # Simple optimization logic - in production would be more sophisticated
    state.policy_adaptations
    |> Enum.filter(fn {_data_key, {_policy, timestamp}} ->
      # Consider adaptations older than 1 hour for re-evaluation
      System.system_time(:second) - timestamp > 3600
    end)
    |> Enum.map(fn {data_key, {policy, _timestamp}} ->
      # Suggest moving cold data to cheaper storage
      current_tier = policy.primary_tier
      recommended_tier = if current_tier == :ets, do: :mnesia, else: current_tier
      {data_key, recommended_tier, :cost_optimization}
    end)
  end

  defp handle_memory_pressure_internal(severity, state) do
    case severity do
      :low ->
        # Migrate some ETS data to Mnesia
        migrate_by_pressure(:ets, :mnesia, 0.1, state)

      :medium ->
        # More aggressive migration
        migrate_by_pressure(:ets, :mnesia, 0.25, state)

      :high ->
        # Emergency migration
        state = migrate_by_pressure(:ets, :mnesia, 0.5, state)
        migrate_by_pressure(:mnesia, :dets, 0.3, state)
    end
  end

  defp migrate_by_pressure(from_tier, to_tier, percentage, state) do
    # Get utilization info
    from_utilization = Map.get(state.tier_utilization, from_tier)
    items_to_migrate = round(from_utilization.item_count * percentage)

    # Queue migrations (simplified - would identify actual data keys)
    migration_tasks =
      Enum.map(1..items_to_migrate, fn i ->
        {:migrate, "placeholder_key_#{i}", from_tier, to_tier, :memory_pressure}
      end)

    new_queue =
      Enum.reduce(migration_tasks, state.migration_queue, fn task, queue ->
        :queue.in(task, queue)
      end)

    %{state | migration_queue: new_queue}
  end

  defp process_migration_queue(state) do
    case :queue.out(state.migration_queue) do
      {{:value, {:migrate, data_key, _from_tier, to_tier, reason}}, new_queue} ->
        # Process migration
        case execute_tier_migration(data_key, to_tier, reason, state) do
          {:ok, _result, new_state} ->
            %{new_state | migration_queue: new_queue}

          {:error, _reason} ->
            %{state | migration_queue: new_queue}
        end

      {:empty, _} ->
        state
    end
  end

  defp perform_periodic_optimization(state) do
    # Update tier monitoring first
    state = update_tier_monitoring(state)

    # Perform lightweight optimization
    perform_storage_optimization(state)
  end

  defp update_tier_monitoring(state) do
    # Update monitoring data for each tier
    new_utilization =
      Map.new(@storage_tiers, fn tier ->
        current_stats = get_tier_current_stats(tier)
        {tier, current_stats}
      end)

    %{state | tier_utilization: new_utilization}
  end

  defp get_tier_current_stats(:ets) do
    # Get ETS statistics
    stats = EtsGraphStore.get_stats()

    %{
      memory_used:
        stats.memory_usage.nodes + stats.memory_usage.edges + stats.memory_usage.indexes,
      memory_limit: get_ets_memory_limit(),
      item_count: stats.total_nodes + stats.total_edges,
      # Would track actual access rate
      access_rate: 0.0,
      last_updated: System.system_time(:second)
    }
  end

  defp get_tier_current_stats(:mnesia) do
    # Get Mnesia statistics
    case :mnesia.system_info(:is_running) do
      :yes ->
        memory_info = :mnesia.system_info(:db_nodes)

        %{
          # Placeholder
          memory_used: length(memory_info) * 1000,
          memory_limit: get_mnesia_memory_limit(),
          # Would count actual items
          item_count: 0,
          access_rate: 0.0,
          last_updated: System.system_time(:second)
        }

      _ ->
        %{
          memory_used: 0,
          memory_limit: 0,
          item_count: 0,
          access_rate: 0.0,
          last_updated: System.system_time(:second)
        }
    end
  end

  defp get_tier_current_stats(:dets) do
    # Get DETS statistics (placeholder)
    %{
      disk_used: 0,
      disk_limit: get_dets_disk_limit(),
      item_count: 0,
      access_rate: 0.0,
      last_updated: System.system_time(:second)
    }
  end

  defp analyze_data_characteristics(data_key) do
    # Analyze characteristics of specific data
    %{
      access_frequency: get_access_frequency(data_key),
      data_size: get_data_size(data_key),
      # Would analyze actual patterns
      access_pattern: :random,
      retention_requirement: :standard
    }
  end

  defp get_current_storage_tier(data_key) do
    # Determine which tier currently stores the data
    # Note: Only ETS tier is currently implemented
    if data_exists_in_ets?(data_key) do
      :ets
    else
      :unknown
    end
  end

  defp get_data_from_current_tier(data_key) do
    # Retrieve data from its current storage tier
    # Note: Only ETS tier is currently implemented
    case get_current_storage_tier(data_key) do
      :ets -> get_data_from_ets(data_key)
      :unknown -> {:error, :data_not_found}
    end
  end

  defp store_data_in_tier(data_key, data, tier) do
    case tier do
      :ets -> store_data_in_ets(data_key, data)
      :mnesia -> store_data_in_mnesia(data_key, data)
      :dets -> store_data_in_dets(data_key, data)
    end
  end

  defp remove_data_from_tier(data_key, :ets) do
    remove_data_from_ets(data_key)
  end

  defp update_tier_utilization_after_migration(_data_key, data, from_tier, to_tier, state) do
    data_size = :erlang.external_size(data)

    # Update from_tier utilization
    from_util = Map.get(state.tier_utilization, from_tier)

    updated_from_util = %{
      from_util
      | memory_used: max(0, from_util.memory_used - data_size),
        item_count: max(0, from_util.item_count - 1)
    }

    # Update to_tier utilization
    to_util = Map.get(state.tier_utilization, to_tier)

    updated_to_util = %{
      to_util
      | memory_used: to_util.memory_used + data_size,
        item_count: to_util.item_count + 1
    }

    new_utilization =
      state.tier_utilization
      |> Map.put(from_tier, updated_from_util)
      |> Map.put(to_tier, updated_to_util)

    %{state | tier_utilization: new_utilization}
  end

  defp calculate_cost_efficiency(state) do
    # Calculate overall cost efficiency across all tiers
    total_cost =
      @storage_tiers
      |> Enum.map(fn tier ->
        utilization = Map.get(state.tier_utilization, tier)
        cost_model = Map.get(state.cost_models, tier)

        memory_cost =
          utilization.memory_used / 1_048_576 * Map.get(cost_model, :memory_cost_per_mb, 0)

        maintenance_cost = Map.get(cost_model, :maintenance_cost, 0)

        memory_cost + maintenance_cost
      end)
      |> Enum.sum()

    total_items =
      @storage_tiers
      |> Enum.map(fn tier ->
        utilization = Map.get(state.tier_utilization, tier)
        utilization.item_count
      end)
      |> Enum.sum()

    if total_items > 0 do
      total_cost / total_items
    else
      0.0
    end
  end

  # Helper functions for tier operations
  defp data_exists_in_ets?(data_key) do
    try do
      node_id = String.to_integer(data_key)

      case EtsGraphStore.get_node(node_id) do
        {:ok, _} -> true
        _ -> false
      end
    catch
      _ -> false
    end
  end

  defp get_data_from_ets(data_key) do
    try do
      node_id = String.to_integer(data_key)

      case EtsGraphStore.get_node(node_id) do
        {:ok, node} -> {:ok, node, :ets}
        error -> error
      end
    catch
      _ -> {:error, :invalid_key}
    end
  end

  # Placeholder
  defp store_data_in_ets(_data_key, _data), do: :ok
  # Placeholder
  defp store_data_in_mnesia(_data_key, _data), do: :ok
  # Placeholder
  defp store_data_in_dets(_data_key, _data), do: :ok

  # Placeholder
  defp remove_data_from_ets(_data_key), do: :ok

  # Placeholder
  defp get_access_frequency(_data_key), do: 10
  # Placeholder
  defp get_data_size(_data_key), do: 1024

  # 100MB
  defp get_ets_memory_limit, do: 100_000_000
  # 500MB
  defp get_mnesia_memory_limit, do: 500_000_000
  # 10GB
  defp get_dets_disk_limit, do: 10_000_000_000

  defp schedule_optimization do
    # Every 5 minutes
    Process.send_after(self(), :periodic_optimization, 300_000)
  end

  defp schedule_tier_monitoring do
    # Every minute
    Process.send_after(self(), :tier_monitoring, 60_000)
  end

  defp schedule_migration_processing do
    # Every 10 seconds
    Process.send_after(self(), :process_migration_queue, 10_000)
  end
end
