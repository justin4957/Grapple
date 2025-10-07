defmodule Grapple.Storage.GraphStore do
  @moduledoc """
  DETS-based graph storage layer for nodes and edges.
  Handles persistence and basic CRUD operations.
  """

  use GenServer

  defstruct [:nodes_table, :edges_table, :node_id_counter, :edge_id_counter]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    nodes_table = :dets.open_file(:nodes, [{:type, :set}])
    edges_table = :dets.open_file(:edges, [{:type, :bag}])

    state = %__MODULE__{
      nodes_table: nodes_table,
      edges_table: edges_table,
      node_id_counter: get_max_id(:nodes) + 1,
      edge_id_counter: get_max_id(:edges) + 1
    }

    {:ok, state}
  end

  def create_node(properties \\ %{}) do
    GenServer.call(__MODULE__, {:create_node, properties})
  end

  def create_edge(from_node, to_node, label, properties \\ %{}) do
    GenServer.call(__MODULE__, {:create_edge, from_node, to_node, label, properties})
  end

  def get_node(node_id) do
    GenServer.call(__MODULE__, {:get_node, node_id})
  end

  def get_edges_from(node_id) do
    GenServer.call(__MODULE__, {:get_edges_from, node_id})
  end

  def handle_call({:create_node, properties}, _from, state) do
    node_id = state.node_id_counter
    node = %{id: node_id, properties: properties}

    :dets.insert(elem(state.nodes_table, 1), {node_id, node})

    new_state = %{state | node_id_counter: node_id + 1}
    {:reply, {:ok, node_id}, new_state}
  end

  def handle_call({:create_edge, from_node, to_node, label, properties}, _from, state) do
    edge_id = state.edge_id_counter
    edge = %{id: edge_id, from: from_node, to: to_node, label: label, properties: properties}

    :dets.insert(elem(state.edges_table, 1), {from_node, edge})

    new_state = %{state | edge_id_counter: edge_id + 1}
    {:reply, {:ok, edge_id}, new_state}
  end

  def handle_call({:get_node, node_id}, _from, state) do
    case :dets.lookup(elem(state.nodes_table, 1), node_id) do
      [{^node_id, node}] -> {:reply, {:ok, node}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get_edges_from, node_id}, _from, state) do
    edges = :dets.lookup(elem(state.edges_table, 1), node_id)
    {:reply, {:ok, edges}, state}
  end

  defp get_max_id(table) do
    case :dets.open_file(table, [{:type, :set}]) do
      {:ok, ref} ->
        max_id = :dets.foldl(fn {id, _}, acc -> max(id, acc) end, 0, ref)
        :dets.close(ref)
        max_id

      {:error, _} ->
        0
    end
  end
end
