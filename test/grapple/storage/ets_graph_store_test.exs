defmodule Grapple.Storage.EtsGraphStoreTest do
  use ExUnit.Case
  alias Grapple.Storage.EtsGraphStore

  setup do
    # Ensure the ETS graph store is started
    case EtsGraphStore.start_link() do
      {:ok, pid} -> {:ok, store: pid}
      {:error, {:already_started, pid}} -> {:ok, store: pid}
    end

    # Clear any existing data
    try do
      :ets.delete_all_objects(:grapple_nodes)
      :ets.delete_all_objects(:grapple_edges)
      :ets.delete_all_objects(:grapple_node_edges_out)
      :ets.delete_all_objects(:grapple_node_edges_in)
      :ets.delete_all_objects(:grapple_property_index)
      :ets.delete_all_objects(:grapple_label_index)
    catch
      _ -> :ok
    end

    :ok
  end

  describe "node operations" do
    test "create_node/1 creates node with properties" do
      properties = %{name: "Alice", age: 30, role: "Engineer"}
      assert {:ok, node_id} = EtsGraphStore.create_node(properties)
      assert is_integer(node_id)
      assert node_id > 0
    end

    test "create_node/0 creates empty node" do
      assert {:ok, node_id} = EtsGraphStore.create_node()
      assert is_integer(node_id)
    end

    test "get_node/1 retrieves existing node" do
      properties = %{name: "Bob"}
      {:ok, node_id} = EtsGraphStore.create_node(properties)

      assert {:ok, node} = EtsGraphStore.get_node(node_id)
      assert node.id == node_id
      assert node.properties == properties
    end

    test "get_node/1 returns error for nonexistent node" do
      assert {:error, :not_found} = EtsGraphStore.get_node(999_999)
    end

    test "delete_node/1 removes node" do
      {:ok, node_id} = EtsGraphStore.create_node(%{name: "Test"})

      assert :ok = EtsGraphStore.delete_node(node_id)
      assert {:error, :not_found} = EtsGraphStore.get_node(node_id)
    end

    test "delete_node/1 handles nonexistent node" do
      result = EtsGraphStore.delete_node(999_999)
      # May return :ok or error depending on implementation
      assert result in [:ok, {:error, :not_found}]
    end
  end

  describe "edge operations" do
    test "create_edge/4 creates edge with properties" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})

      properties = %{since: "2020", strength: "strong"}
      assert {:ok, edge_id} = EtsGraphStore.create_edge(node1, node2, "knows", properties)
      assert is_integer(edge_id)
    end

    test "create_edge/3 creates edge without properties" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})

      assert {:ok, edge_id} = EtsGraphStore.create_edge(node1, node2, "follows")
      assert is_integer(edge_id)
    end

    test "create_edge/4 validates node existence" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})

      result = EtsGraphStore.create_edge(node1, 999_999, "knows")
      assert {:error, :node_not_found, _, _} = result

      result2 = EtsGraphStore.create_edge(999_999, node1, "knows")
      assert {:error, :node_not_found, _, _} = result2
    end

    test "get_edge/1 retrieves existing edge" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, edge_id} = EtsGraphStore.create_edge(node1, node2, "knows", %{weight: 10})

      assert {:ok, edge} = EtsGraphStore.get_edge(edge_id)
      assert edge.id == edge_id
      assert edge.from == node1
      assert edge.to == node2
      assert edge.label == "knows"
      assert edge.properties.weight == 10
    end

    test "get_edges_from/1 returns edges from node" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, node3} = EtsGraphStore.create_node(%{name: "Carol"})

      {:ok, _edge1} = EtsGraphStore.create_edge(node1, node2, "knows")
      {:ok, _edge2} = EtsGraphStore.create_edge(node1, node3, "knows")

      {:ok, edges} = EtsGraphStore.get_edges_from(node1)

      assert length(edges) == 2
      assert Enum.all?(edges, fn edge -> edge.from == node1 end)
    end

    test "get_edges_to/1 returns edges to node" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, node3} = EtsGraphStore.create_node(%{name: "Carol"})

      {:ok, _edge1} = EtsGraphStore.create_edge(node2, node1, "knows")
      {:ok, _edge2} = EtsGraphStore.create_edge(node3, node1, "knows")

      {:ok, edges} = EtsGraphStore.get_edges_to(node1)

      assert length(edges) == 2
      assert Enum.all?(edges, fn edge -> edge.to == node1 end)
    end
  end

  describe "property indexing" do
    test "find_nodes_by_property/2 finds matching nodes" do
      {:ok, _} = EtsGraphStore.create_node(%{role: "Engineer", name: "Alice"})
      {:ok, _} = EtsGraphStore.create_node(%{role: "Engineer", name: "Bob"})
      {:ok, _} = EtsGraphStore.create_node(%{role: "Manager", name: "Carol"})

      {:ok, engineers} = EtsGraphStore.find_nodes_by_property(:role, "Engineer")

      assert length(engineers) == 2
      assert Enum.all?(engineers, fn node -> node.properties.role == "Engineer" end)
    end

    test "find_nodes_by_property/2 returns empty list for no matches" do
      {:ok, _} = EtsGraphStore.create_node(%{role: "Engineer"})

      {:ok, nodes} = EtsGraphStore.find_nodes_by_property(:role, "CEO")

      assert nodes == []
    end

    test "property index is updated on node creation" do
      {:ok, node1} = EtsGraphStore.create_node(%{category: "test"})
      {:ok, nodes1} = EtsGraphStore.find_nodes_by_property(:category, "test")
      assert length(nodes1) == 1

      {:ok, node2} = EtsGraphStore.create_node(%{category: "test"})
      {:ok, nodes2} = EtsGraphStore.find_nodes_by_property(:category, "test")
      assert length(nodes2) == 2
    end
  end

  describe "label indexing" do
    test "find_edges_by_label/1 finds matching edges" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, node3} = EtsGraphStore.create_node(%{name: "Carol"})

      {:ok, _} = EtsGraphStore.create_edge(node1, node2, "knows")
      {:ok, _} = EtsGraphStore.create_edge(node2, node3, "knows")
      {:ok, _} = EtsGraphStore.create_edge(node1, node3, "follows")

      {:ok, knows_edges} = EtsGraphStore.find_edges_by_label("knows")

      assert length(knows_edges) == 2
      assert Enum.all?(knows_edges, fn edge -> edge.label == "knows" end)
    end

    test "find_edges_by_label/1 returns empty list for no matches" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, _} = EtsGraphStore.create_edge(node1, node2, "knows")

      {:ok, edges} = EtsGraphStore.find_edges_by_label("loves")

      assert edges == []
    end
  end

  describe "statistics" do
    test "get_stats/0 returns accurate counts" do
      initial_stats = EtsGraphStore.get_stats()

      {:ok, node1} = EtsGraphStore.create_node(%{name: "Alice"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Bob"})
      {:ok, _edge} = EtsGraphStore.create_edge(node1, node2, "knows")

      stats = EtsGraphStore.get_stats()

      assert stats.total_nodes == initial_stats.total_nodes + 2
      assert stats.total_edges == initial_stats.total_edges + 1
    end

    test "get_stats/0 includes memory usage" do
      stats = EtsGraphStore.get_stats()

      assert Map.has_key?(stats, :memory_usage)
      assert Map.has_key?(stats.memory_usage, :nodes)
      assert Map.has_key?(stats.memory_usage, :edges)
      assert Map.has_key?(stats.memory_usage, :indexes)

      assert is_integer(stats.memory_usage.nodes)
      assert is_integer(stats.memory_usage.edges)
      assert is_integer(stats.memory_usage.indexes)
    end
  end

  describe "concurrent operations" do
    test "handles concurrent node creation" do
      tasks =
        Enum.map(1..20, fn i ->
          Task.async(fn ->
            EtsGraphStore.create_node(%{id: i, name: "Node#{i}"})
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # All IDs should be unique
      ids = Enum.map(results, fn {:ok, id} -> id end)
      assert length(Enum.uniq(ids)) == 20
    end

    test "handles concurrent edge creation" do
      {:ok, node1} = EtsGraphStore.create_node(%{name: "Source"})
      {:ok, node2} = EtsGraphStore.create_node(%{name: "Target"})

      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            EtsGraphStore.create_edge(node1, node2, "test", %{seq: i})
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # All IDs should be unique
      ids = Enum.map(results, fn {:ok, id} -> id end)
      assert length(Enum.uniq(ids)) == 10
    end
  end
end
