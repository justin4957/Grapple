defmodule Grapple.Cluster.NodeManager do
  @moduledoc """
  Manages cluster membership and node discovery.
  Handles distribution of graph data across nodes.
  """

  use GenServer

  defstruct [:nodes, :local_node, :partition_ring]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    local_node = Node.self()
    :net_kernel.monitor_nodes(true)
    
    state = %__MODULE__{
      nodes: [local_node],
      local_node: local_node,
      partition_ring: build_partition_ring([local_node])
    }
    
    {:ok, state}
  end

  def join_cluster(node_name) do
    GenServer.call(__MODULE__, {:join_cluster, node_name})
  end

  def get_partition_for_key(key) do
    GenServer.call(__MODULE__, {:get_partition, key})
  end

  def get_cluster_info do
    GenServer.call(__MODULE__, :get_cluster_info)
  end

  def handle_call({:join_cluster, node_name}, _from, state) do
    case Node.connect(node_name) do
      true ->
        new_nodes = [node_name | state.nodes] |> Enum.uniq()
        new_ring = build_partition_ring(new_nodes)
        new_state = %{state | nodes: new_nodes, partition_ring: new_ring}
        {:reply, {:ok, :connected}, new_state}

      false ->
        {:reply, {:error, :connection_failed}, state}

      :ignored ->
        # Node is already connected or connection attempt was ignored
        if node_name in state.nodes do
          {:reply, {:ok, :already_connected}, state}
        else
          new_nodes = [node_name | state.nodes] |> Enum.uniq()
          new_ring = build_partition_ring(new_nodes)
          new_state = %{state | nodes: new_nodes, partition_ring: new_ring}
          {:reply, {:ok, :connected}, new_state}
        end
    end
  end

  def handle_call({:get_partition, key}, _from, state) do
    hash = :erlang.phash2(key, 256)
    node = get_node_for_hash(hash, state.partition_ring)
    {:reply, node, state}
  end

  def handle_call(:get_cluster_info, _from, state) do
    info = %{
      nodes: state.nodes,
      local_node: state.local_node,
      partitions: length(state.partition_ring)
    }
    {:reply, info, state}
  end

  def handle_info({:nodeup, node}, state) do
    new_nodes = [node | state.nodes] |> Enum.uniq()
    new_ring = build_partition_ring(new_nodes)
    new_state = %{state | nodes: new_nodes, partition_ring: new_ring}
    {:noreply, new_state}
  end

  def handle_info({:nodedown, node}, state) do
    new_nodes = List.delete(state.nodes, node)
    new_ring = build_partition_ring(new_nodes)
    new_state = %{state | nodes: new_nodes, partition_ring: new_ring}
    {:noreply, new_state}
  end

  defp build_partition_ring(nodes) do
    partitions_per_node = 64
    
    nodes
    |> Enum.flat_map(fn node ->
      0..(partitions_per_node - 1)
      |> Enum.map(fn i -> {:erlang.phash2({node, i}, 256), node} end)
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp get_node_for_hash(hash, ring) do
    case Enum.find(ring, fn {partition_hash, _node} -> partition_hash >= hash end) do
      {_hash, node} -> node
      nil -> ring |> List.first() |> elem(1)
    end
  end
end