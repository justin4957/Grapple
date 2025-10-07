defmodule Grapple.Distributed.HealthMonitor do
  @moduledoc """
  Minimal self-healing health monitoring.
  Detects failures and triggers basic recovery - unfurling ready.
  """

  use GenServer

  @heartbeat_interval 5_000
  @failure_threshold 3
  @recovery_timeout 30_000

  defstruct [
    :local_node,
    :monitored_nodes,
    :failure_counts,
    :recovery_tasks
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Start with basic monitoring
    state = %__MODULE__{
      local_node: node(),
      monitored_nodes: MapSet.new(),
      failure_counts: %{},
      recovery_tasks: %{}
    }

    # Start heartbeat timer
    schedule_heartbeat()

    # Monitor node events
    :net_kernel.monitor_nodes(true)

    {:ok, state}
  end

  # Public API
  def get_cluster_health do
    GenServer.call(__MODULE__, :get_cluster_health)
  end

  def force_health_check do
    GenServer.cast(__MODULE__, :force_health_check)
  end

  # GenServer callbacks
  def handle_call(:get_cluster_health, _from, state) do
    cluster_health = %{
      local_node: state.local_node,
      monitored_nodes: MapSet.to_list(state.monitored_nodes),
      failed_nodes: get_failed_nodes(state),
      recovering_nodes: Map.keys(state.recovery_tasks),
      overall_status: calculate_overall_status(state)
    }

    {:reply, cluster_health, state}
  end

  def handle_cast(:force_health_check, state) do
    new_state = perform_health_check(state)
    {:noreply, new_state}
  end

  def handle_info(:heartbeat, state) do
    # Perform regular health monitoring
    new_state = perform_health_check(state)

    # Schedule next heartbeat
    schedule_heartbeat()

    {:noreply, new_state}
  end

  def handle_info({:nodeup, node}, state) do
    # New node joined - start monitoring it
    new_monitored = MapSet.put(state.monitored_nodes, node)
    new_failure_counts = Map.put(state.failure_counts, node, 0)

    # Cancel any recovery tasks for this node
    new_recovery_tasks = Map.delete(state.recovery_tasks, node)

    new_state = %{
      state
      | monitored_nodes: new_monitored,
        failure_counts: new_failure_counts,
        recovery_tasks: new_recovery_tasks
    }

    {:noreply, new_state}
  end

  def handle_info({:nodedown, node}, state) do
    # Node went down - increment failure count
    current_failures = Map.get(state.failure_counts, node, 0)
    new_failure_counts = Map.put(state.failure_counts, node, current_failures + 1)

    new_state = %{state | failure_counts: new_failure_counts}

    # Check if this constitutes a failure
    if current_failures + 1 >= @failure_threshold do
      handle_node_failure(node, new_state)
    else
      {:noreply, new_state}
    end
  end

  def handle_info({:recovery_timeout, node}, state) do
    # Recovery timed out - remove from recovery tasks
    new_recovery_tasks = Map.delete(state.recovery_tasks, node)
    new_state = %{state | recovery_tasks: new_recovery_tasks}

    # Mark node as permanently failed (for now)
    mark_node_as_failed(node)

    {:noreply, new_state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  # Private functions
  defp perform_health_check(state) do
    # Get current cluster state
    cluster_info = Grapple.Distributed.ClusterManager.get_cluster_info()
    active_nodes = MapSet.new(cluster_info.nodes)

    # Update monitored nodes
    new_monitored = MapSet.union(state.monitored_nodes, active_nodes)

    # Reset failure counts for nodes that are back up
    new_failure_counts =
      state.failure_counts
      |> Enum.filter(fn {node, _count} -> not MapSet.member?(active_nodes, node) end)
      |> Enum.into(%{})

    %{state | monitored_nodes: new_monitored, failure_counts: new_failure_counts}
  end

  defp handle_node_failure(failed_node, state) do
    # Trigger basic recovery procedures
    recovery_ref = start_node_recovery(failed_node)

    new_recovery_tasks = Map.put(state.recovery_tasks, failed_node, recovery_ref)
    new_state = %{state | recovery_tasks: new_recovery_tasks}

    {:noreply, new_state}
  end

  defp start_node_recovery(failed_node) do
    # Schedule recovery timeout
    recovery_ref = make_ref()
    Process.send_after(self(), {:recovery_timeout, failed_node}, @recovery_timeout)

    # Start basic recovery procedures in background
    spawn(fn -> execute_node_recovery(failed_node) end)

    recovery_ref
  end

  defp execute_node_recovery(failed_node) do
    # Basic recovery steps - can be enhanced later

    # 1. Wait a moment for transient failures
    :timer.sleep(1000)

    # 2. Attempt to reconnect
    case Node.connect(failed_node) do
      true ->
        # Node reconnected successfully
        :ok

      false ->
        # 3. Redistribute data partitions (minimal implementation)
        redistribute_partitions_from_failed_node(failed_node)

        # 4. Update cluster state
        update_cluster_after_failure(failed_node)
    end
  end

  defp redistribute_partitions_from_failed_node(failed_node) do
    # Minimal implementation - just log for now
    # Real implementation would redistribute data partitions
    :error_logger.info_msg("Redistributing partitions from failed node: ~p~n", [failed_node])
  end

  defp update_cluster_after_failure(failed_node) do
    # Update Mnesia records to reflect node failure
    :mnesia.transaction(fn ->
      case :mnesia.read(:cluster_nodes, failed_node) do
        [{:cluster_nodes, ^failed_node, _, join_time, capabilities}] ->
          :mnesia.write({:cluster_nodes, failed_node, :failed, join_time, capabilities})

        [] ->
          :ok
      end
    end)
  end

  defp mark_node_as_failed(node) do
    update_cluster_after_failure(node)
  end

  defp get_failed_nodes(state) do
    state.failure_counts
    |> Enum.filter(fn {_node, count} -> count >= @failure_threshold end)
    |> Enum.map(fn {node, _count} -> node end)
  end

  defp calculate_overall_status(state) do
    total_monitored = MapSet.size(state.monitored_nodes)
    failed_count = length(get_failed_nodes(state))

    cond do
      total_monitored == 0 -> :unknown
      failed_count == 0 -> :healthy
      failed_count < total_monitored / 2 -> :degraded
      true -> :critical
    end
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
end
