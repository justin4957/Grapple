defmodule Grapple.Storage.EtsGraphStore do
  @moduledoc """
  High-performance ETS-based in-memory graph storage.
  Provides O(1) lookups, advanced indexing, and concurrent access.
  """

  use GenServer
  alias Grapple.{Validation, Error}

  defstruct [
    :nodes_table,
    :edges_table,
    :node_edges_out_table,
    :node_edges_in_table,
    :property_index_table,
    :label_index_table,
    :node_id_counter,
    :edge_id_counter
  ]

  # Table names
  @nodes_table :grapple_nodes
  @edges_table :grapple_edges
  @node_edges_out_table :grapple_node_edges_out
  @node_edges_in_table :grapple_node_edges_in
  @property_index_table :grapple_property_index
  @label_index_table :grapple_label_index

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Create ETS tables with optimized configurations
    nodes_table =
      create_table(@nodes_table, [:set, :named_table, :public, {:read_concurrency, true}])

    edges_table =
      create_table(@edges_table, [:set, :named_table, :public, {:read_concurrency, true}])

    node_edges_out_table =
      create_table(@node_edges_out_table, [:set, :named_table, :public, {:read_concurrency, true}])

    node_edges_in_table =
      create_table(@node_edges_in_table, [:set, :named_table, :public, {:read_concurrency, true}])

    property_index_table =
      create_table(@property_index_table, [:bag, :named_table, :public, {:read_concurrency, true}])

    label_index_table =
      create_table(@label_index_table, [:bag, :named_table, :public, {:read_concurrency, true}])

    # Initialize query cache
    Grapple.Query.EtsOptimizer.init_cache()

    state = %__MODULE__{
      nodes_table: nodes_table,
      edges_table: edges_table,
      node_edges_out_table: node_edges_out_table,
      node_edges_in_table: node_edges_in_table,
      property_index_table: property_index_table,
      label_index_table: label_index_table,
      node_id_counter: 1,
      edge_id_counter: 1
    }

    {:ok, state}
  end

  # Public API
  def create_node(properties \\ %{}) do
    GenServer.call(__MODULE__, {:create_node, properties})
  end

  def create_edge(from_node, to_node, label, properties \\ %{}) do
    GenServer.call(__MODULE__, {:create_edge, from_node, to_node, label, properties})
  end

  def get_node(node_id) do
    case :ets.lookup(@nodes_table, node_id) do
      [{^node_id, node_data}] -> {:ok, node_data}
      [] -> {:error, :not_found}
    end
  end

  def get_edge(edge_id) do
    case :ets.lookup(@edges_table, edge_id) do
      [{^edge_id, edge_data}] -> {:ok, edge_data}
      [] -> {:error, :not_found}
    end
  end

  def get_edges_from(node_id) do
    case :ets.lookup(@node_edges_out_table, node_id) do
      [{^node_id, edge_ids}] ->
        edges =
          edge_ids
          |> Enum.map(fn edge_id ->
            case :ets.lookup(@edges_table, edge_id) do
              [{^edge_id, edge_data}] -> {node_id, edge_data}
              [] -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, edges}

      [] ->
        {:ok, []}
    end
  end

  def get_edges_to(node_id) do
    case :ets.lookup(@node_edges_in_table, node_id) do
      [{^node_id, edge_ids}] ->
        edges =
          edge_ids
          |> Enum.map(fn edge_id ->
            case :ets.lookup(@edges_table, edge_id) do
              [{^edge_id, edge_data}] -> {edge_data.from, edge_data}
              [] -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, edges}

      [] ->
        {:ok, []}
    end
  end

  def find_nodes_by_property(key, value) do
    case :ets.lookup(@property_index_table, {key, value}) do
      objects ->
        node_ids = objects |> Enum.map(fn {{_key, _value}, node_id} -> node_id end)

        nodes =
          node_ids
          |> Enum.map(fn node_id ->
            case get_node(node_id) do
              {:ok, node} -> node
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, nodes}
    end
  end

  def find_edges_by_label(label) do
    case :ets.lookup(@label_index_table, label) do
      objects ->
        edge_ids = objects |> Enum.map(fn {_label, edge_id} -> edge_id end)

        edges =
          edge_ids
          |> Enum.map(fn edge_id ->
            case get_edge(edge_id) do
              {:ok, edge} -> edge
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, edges}
    end
  end

  def delete_node(node_id) do
    GenServer.call(__MODULE__, {:delete_node, node_id})
  end

  def delete_edge(edge_id) do
    GenServer.call(__MODULE__, {:delete_edge, edge_id})
  end

  def list_nodes do
    nodes =
      :ets.tab2list(@nodes_table)
      |> Enum.map(fn {_id, node_data} -> node_data end)

    {:ok, nodes}
  end

  def list_edges do
    edges =
      :ets.tab2list(@edges_table)
      |> Enum.map(fn {_id, edge_data} -> edge_data end)

    {:ok, edges}
  end

  def get_stats do
    %{
      total_nodes: :ets.info(@nodes_table, :size),
      total_edges: :ets.info(@edges_table, :size),
      memory_usage: %{
        nodes: :ets.info(@nodes_table, :memory),
        edges: :ets.info(@edges_table, :memory),
        indexes:
          :ets.info(@property_index_table, :memory) + :ets.info(@label_index_table, :memory)
      }
    }
  end

  # GenServer callbacks
  def handle_call({:create_node, properties}, _from, state) do
    case Validation.validate_node_properties(properties) do
      {:ok, validated_properties} ->
        node_id = state.node_id_counter
        node_data = %{id: node_id, properties: validated_properties}

        # Insert node
        :ets.insert(state.nodes_table, {node_id, node_data})

        # Initialize adjacency lists
        :ets.insert(state.node_edges_out_table, {node_id, []})
        :ets.insert(state.node_edges_in_table, {node_id, []})

        # Index properties
        Enum.each(validated_properties, fn {key, value} ->
          :ets.insert(state.property_index_table, {{key, value}, node_id})
        end)

        # Index for full-text search
        try do
          Grapple.Search.index_node(node_id, validated_properties)
        rescue
          _ -> :ok
        end

        new_state = %{state | node_id_counter: node_id + 1}
        {:reply, {:ok, node_id}, new_state}

      {:error, _reason, _message, _opts} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:create_edge, from_node, to_node, label, properties}, _from, state) do
    with {:ok, _from_id} <- Validation.validate_id(from_node),
         {:ok, _to_id} <- Validation.validate_id(to_node),
         {:ok, validated_label} <- Validation.validate_edge_label(label),
         {:ok, validated_properties} <- Validation.validate_node_properties(properties),
         {:ok, _from_node_data} <- verify_node_exists(from_node),
         {:ok, _to_node_data} <- verify_node_exists(to_node) do
      edge_id = state.edge_id_counter

      edge_data = %{
        id: edge_id,
        from: from_node,
        to: to_node,
        label: validated_label,
        properties: validated_properties
      }

      # Insert edge
      :ets.insert(state.edges_table, {edge_id, edge_data})

      # Update adjacency lists
      update_adjacency_list(state.node_edges_out_table, from_node, edge_id, :add)
      update_adjacency_list(state.node_edges_in_table, to_node, edge_id, :add)

      # Index label
      :ets.insert(state.label_index_table, {validated_label, edge_id})

      new_state = %{state | edge_id_counter: edge_id + 1}
      {:reply, {:ok, edge_id}, new_state}
    else
      {:error, _reason, _message, _opts} = error ->
        {:reply, error, state}

      {:error, :not_found} ->
        {:reply, Error.node_not_found("from_node or to_node"), state}
    end
  end

  def handle_call({:delete_node, node_id}, _from, state) do
    case get_node(node_id) do
      {:ok, node} ->
        # Remove all edges connected to this node
        {:ok, outgoing_edges} = get_edges_from(node_id)
        {:ok, incoming_edges} = get_edges_to(node_id)

        all_edges = outgoing_edges ++ incoming_edges

        Enum.each(all_edges, fn {_from, edge} ->
          delete_edge_internal(edge.id, state)
        end)

        # Remove property indexes
        Enum.each(node.properties, fn {key, value} ->
          :ets.delete_object(state.property_index_table, {{key, value}, node_id})
        end)

        # Remove from full-text search index
        try do
          Grapple.Search.remove_node(node_id)
        rescue
          _ -> :ok
        end

        # Remove node and adjacency lists
        :ets.delete(state.nodes_table, node_id)
        :ets.delete(state.node_edges_out_table, node_id)
        :ets.delete(state.node_edges_in_table, node_id)

        {:reply, :ok, state}

      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete_edge, edge_id}, _from, state) do
    result = delete_edge_internal(edge_id, state)
    {:reply, result, state}
  end

  # Private functions
  defp verify_node_exists(node_id) do
    get_node(node_id)
  end

  defp create_table(name, opts) do
    case :ets.info(name) do
      :undefined ->
        :ets.new(name, opts)

      _ ->
        :ets.delete(name)
        :ets.new(name, opts)
    end
  end

  defp update_adjacency_list(table, node_id, edge_id, :add) do
    case :ets.lookup(table, node_id) do
      [{^node_id, edge_ids}] ->
        new_edge_ids = [edge_id | edge_ids] |> Enum.uniq()
        :ets.insert(table, {node_id, new_edge_ids})

      [] ->
        :ets.insert(table, {node_id, [edge_id]})
    end
  end

  defp update_adjacency_list(table, node_id, edge_id, :remove) do
    case :ets.lookup(table, node_id) do
      [{^node_id, edge_ids}] ->
        new_edge_ids = List.delete(edge_ids, edge_id)
        :ets.insert(table, {node_id, new_edge_ids})

      [] ->
        :ok
    end
  end

  defp delete_edge_internal(edge_id, state) do
    case get_edge(edge_id) do
      {:ok, edge} ->
        # Remove from adjacency lists
        update_adjacency_list(state.node_edges_out_table, edge.from, edge_id, :remove)
        update_adjacency_list(state.node_edges_in_table, edge.to, edge_id, :remove)

        # Remove from label index
        :ets.delete_object(state.label_index_table, {edge.label, edge_id})

        # Remove edge
        :ets.delete(state.edges_table, edge_id)

        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def terminate(_reason, state) do
    # Clean up ETS tables
    :ets.delete(state.nodes_table)
    :ets.delete(state.edges_table)
    :ets.delete(state.node_edges_out_table)
    :ets.delete(state.node_edges_in_table)
    :ets.delete(state.property_index_table)
    :ets.delete(state.label_index_table)
    :ok
  end
end
