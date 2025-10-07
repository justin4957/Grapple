defmodule Grapple.Distributed.ClusterManager do
  @moduledoc """
  Minimal cluster management - designed for unfurling.
  Handles basic node joining, leaving, and coordination with comprehensive error handling.
  """

  use GenServer
  alias Grapple.Distributed.Schema
  alias Grapple.Error

  require Logger

  defstruct [:local_node, :cluster_state, :partition_count]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Start Mnesia if not already running
    ensure_mnesia_started()
    
    # Create schema if it doesn't exist
    ensure_schema_exists()
    
    # Setup schema tables
    Schema.setup_tables()
    
    # Initialize cluster state
    local_node = node()
    partition_count = opts[:partition_count] || 64
    
    state = %__MODULE__{
      local_node: local_node,
      cluster_state: %{nodes: [local_node], partitions: %{}},
      partition_count: partition_count
    }
    
    # Register this node in cluster
    register_local_node()
    
    # Start basic monitoring
    :net_kernel.monitor_nodes(true)
    
    {:ok, state}
  end

  # Public API - minimal for now, can be expanded
  def join_cluster(target_node) when is_atom(target_node) do
    GenServer.call(__MODULE__, {:join_cluster, target_node})
  end

  def get_cluster_info do
    GenServer.call(__MODULE__, :get_cluster_info)
  end

  def get_node_for_key(key) do
    GenServer.call(__MODULE__, {:get_node_for_key, key})
  end

  # GenServer callbacks
  def handle_call({:join_cluster, target_node}, _from, state) do
    case attempt_cluster_join(target_node) do
      :ok ->
        new_state = refresh_cluster_state(state)
        {:reply, {:ok, :joined}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_cluster_info, _from, state) do
    cluster_info = %{
      local_node: state.local_node,
      nodes: get_active_nodes(),
      partition_count: state.partition_count,
      status: :active
    }
    {:reply, cluster_info, state}
  end

  def handle_call({:get_node_for_key, key}, _from, state) do
    # Simple consistent hashing - can be enhanced later
    hash = :erlang.phash2(key, state.partition_count)
    target_node = get_node_for_partition(hash)
    {:reply, target_node, state}
  end

  def handle_info({:nodeup, node}, state) do
    # New node detected - minimal handling for now
    :mnesia.change_config(:extra_db_nodes, [node])
    new_state = refresh_cluster_state(state)
    {:noreply, new_state}
  end

  def handle_info({:nodedown, node}, state) do
    # Node failure detected - basic cleanup
    cleanup_failed_node(node)
    new_state = refresh_cluster_state(state)
    {:noreply, new_state}
  end

  # Private functions - minimal implementations
  defp ensure_mnesia_started do
    case :mnesia.system_info(:is_running) do
      :yes -> :ok
      :no -> 
        :mnesia.start()
        :ok
      :starting -> 
        :timer.sleep(100)
        ensure_mnesia_started()
      :stopping ->
        :timer.sleep(500)
        ensure_mnesia_started()
    end
  end

  defp register_local_node do
    node_info = Schema.ClusterNode.new(node(), get_node_capabilities())
    
    transaction_result = :mnesia.transaction(fn ->
      :mnesia.write({:cluster_nodes, node(), :active, DateTime.utc_now(), node_info.capabilities})
    end)
    
    case transaction_result do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  defp attempt_cluster_join(target_node) do
    Logger.info("Attempting to join cluster at node: #{target_node}")

    case Node.connect(target_node) do
      true ->
        Logger.info("Successfully connected to #{target_node}")

        # Copy schema from target node
        case :mnesia.change_config(:extra_db_nodes, [target_node]) do
          {:ok, nodes} ->
            Logger.info("Joined cluster with nodes: #{inspect(nodes)}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to sync mnesia schema: #{inspect(reason)}")
            {:error, {:schema_sync_failed, reason}}
        end

      :ignored ->
        # Node is already connected
        Logger.info("Node #{target_node} is already connected")

        case :mnesia.change_config(:extra_db_nodes, [target_node]) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, {:schema_sync_failed, reason}}
        end

      false ->
        Logger.error("Failed to connect to node #{target_node}")
        {:error, :connection_failed}
    end
  rescue
    error ->
      Logger.error("Exception during cluster join: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp refresh_cluster_state(state) do
    active_nodes = get_active_nodes()
    
    # Update local cluster state
    %{state | cluster_state: %{
      nodes: active_nodes,
      partitions: calculate_partition_assignments(active_nodes, state.partition_count)
    }}
  end

  defp get_active_nodes do
    case :mnesia.transaction(fn ->
      :mnesia.select(:cluster_nodes, [{{:cluster_nodes, :"$1", :active, :_, :_}, [], [:"$1"]}])
    end) do
      {:atomic, nodes} -> nodes
      {:aborted, _} -> [node()]  # Fallback to local node only
    end
  end

  defp get_node_for_partition(partition_id) do
    active_nodes = get_active_nodes()
    if length(active_nodes) > 0 do
      Enum.at(active_nodes, rem(partition_id, length(active_nodes)))
    else
      node()
    end
  end

  defp calculate_partition_assignments(nodes, partition_count) do
    # Simple round-robin assignment - can be enhanced with consistent hashing later
    nodes
    |> Enum.with_index()
    |> Enum.flat_map(fn {node, index} ->
      assigned_partitions = Stream.iterate(index, &(&1 + length(nodes)))
                           |> Stream.take_while(&(&1 < partition_count))
                           |> Enum.to_list()
      
      Enum.map(assigned_partitions, fn partition_id -> {partition_id, node} end)
    end)
    |> Enum.into(%{})
  end

  defp cleanup_failed_node(failed_node) do
    # Minimal cleanup - mark node as failed
    :mnesia.transaction(fn ->
      case :mnesia.read(:cluster_nodes, failed_node) do
        [{:cluster_nodes, ^failed_node, _, join_time, capabilities}] ->
          :mnesia.write({:cluster_nodes, failed_node, :failed, join_time, capabilities})
        [] ->
          :ok
      end
    end)
  end

  defp get_node_capabilities do
    # Basic capability detection - can be enhanced
    %{
      memory: get_memory_info(),
      cpu_cores: get_cpu_cores(),
      erlang_version: System.version()
    }
  end

  defp get_memory_info do
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory
      _ -> 0
    end
  end

  defp get_cpu_cores do
    case :erlang.system_info(:logical_processors_available) do
      cores when is_integer(cores) -> cores
      _ -> 1
    end
  end

  defp ensure_schema_exists do
    case :mnesia.create_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end