defmodule GrappleTest do
  use ExUnit.Case
  doctest Grapple

  setup do
    # Ensure the ETS graph store is started 
    case Grapple.Storage.EtsGraphStore.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    
    # Clear any existing data for clean tests
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
      assert {:ok, node_id} = Grapple.create_node(properties)
      assert is_integer(node_id)
      assert node_id > 0
    end

    test "create_node/0 creates empty node" do
      assert {:ok, node_id} = Grapple.create_node()
      assert is_integer(node_id)
      assert node_id > 0
    end

    test "get_node/1 retrieves existing node" do
      properties = %{name: "Bob", city: "San Francisco"}
      {:ok, node_id} = Grapple.create_node(properties)
      
      assert {:ok, node} = Grapple.get_node(node_id)
      assert node.id == node_id
      assert node.properties == properties
    end

    test "get_node/1 returns error for non-existent node" do
      assert {:error, :not_found} = Grapple.get_node(99999)
    end

    test "find_nodes_by_property/2 finds nodes with matching property" do
      {:ok, _id1} = Grapple.create_node(%{role: "Engineer", name: "Alice"})
      {:ok, _id2} = Grapple.create_node(%{role: "Engineer", name: "Bob"})
      {:ok, _id3} = Grapple.create_node(%{role: "Manager", name: "Carol"})
      
      assert {:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
      assert length(engineers) == 2
      
      engineer_names = engineers |> Enum.map(& &1.properties.name) |> Enum.sort()
      assert engineer_names == ["Alice", "Bob"]
    end

    test "find_nodes_by_property/2 returns empty list for non-matching property" do
      {:ok, _id} = Grapple.create_node(%{role: "Engineer"})
      
      assert {:ok, []} = Grapple.find_nodes_by_property(:role, "Nonexistent")
    end
  end

  describe "edge operations" do
    test "create_edge/4 creates edge between existing nodes" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      
      assert {:ok, edge_id} = Grapple.create_edge(node1, node2, "friends", %{since: "2020"})
      assert is_integer(edge_id)
      assert edge_id > 0
    end

    test "create_edge/3 creates edge without properties" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      
      assert {:ok, edge_id} = Grapple.create_edge(node1, node2, "knows")
      assert is_integer(edge_id)
    end

    test "create_edge/4 returns error for non-existent nodes" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})

      assert {:error, :node_not_found, _message, _opts} = Grapple.create_edge(node1, 99999, "friends")
      assert {:error, :node_not_found, _message, _opts} = Grapple.create_edge(99999, node1, "friends")
    end

    test "find_edges_by_label/1 finds edges with matching label" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, node3} = Grapple.create_node(%{name: "Carol"})
      
      {:ok, _edge1} = Grapple.create_edge(node1, node2, "friends")
      {:ok, _edge2} = Grapple.create_edge(node2, node3, "friends")
      {:ok, _edge3} = Grapple.create_edge(node1, node3, "knows")
      
      assert {:ok, friend_edges} = Grapple.find_edges_by_label("friends")
      assert length(friend_edges) == 2
      
      assert {:ok, know_edges} = Grapple.find_edges_by_label("knows")
      assert length(know_edges) == 1
    end

    test "find_edges_by_label/1 returns empty list for non-matching label" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, _edge} = Grapple.create_edge(node1, node2, "friends")
      
      assert {:ok, []} = Grapple.find_edges_by_label("nonexistent")
    end
  end

  describe "statistics" do
    test "get_stats/0 returns correct graph statistics" do
      initial_stats = Grapple.get_stats()
      
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, _edge} = Grapple.create_edge(node1, node2, "friends")
      
      stats = Grapple.get_stats()
      
      assert stats.total_nodes == initial_stats.total_nodes + 2
      assert stats.total_edges == initial_stats.total_edges + 1
      assert is_map(stats.memory_usage)
      assert is_integer(stats.memory_usage.nodes)
      assert is_integer(stats.memory_usage.edges)
      assert is_integer(stats.memory_usage.indexes)
    end
  end

  describe "traversal and pathfinding" do
    test "traverse/3 finds neighbors in outgoing direction" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, node3} = Grapple.create_node(%{name: "Carol"})
      
      {:ok, _edge1} = Grapple.create_edge(node1, node2, "friends")
      {:ok, _edge2} = Grapple.create_edge(node1, node3, "knows")
      
      assert {:ok, neighbors} = Grapple.traverse(node1, :out, 1)
      assert length(neighbors) == 2
      
      neighbor_names = neighbors |> Enum.map(& &1.properties.name) |> Enum.sort()
      assert neighbor_names == ["Bob", "Carol"]
    end

    test "traverse/3 finds neighbors in incoming direction" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, node3} = Grapple.create_node(%{name: "Carol"})
      
      {:ok, _edge1} = Grapple.create_edge(node2, node1, "friends")
      {:ok, _edge2} = Grapple.create_edge(node3, node1, "knows")
      
      assert {:ok, neighbors} = Grapple.traverse(node1, :in, 1)
      assert length(neighbors) == 2
      
      neighbor_names = neighbors |> Enum.map(& &1.properties.name) |> Enum.sort()
      assert neighbor_names == ["Bob", "Carol"]
    end

    test "find_path/3 finds shortest path between connected nodes" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      {:ok, node3} = Grapple.create_node(%{name: "Carol"})
      
      {:ok, _edge1} = Grapple.create_edge(node1, node2, "friends")
      {:ok, _edge2} = Grapple.create_edge(node2, node3, "knows")
      
      assert {:ok, path} = Grapple.find_path(node1, node3)
      assert path == [node1, node2, node3]
    end

    test "find_path/3 returns error for unconnected nodes" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      
      assert {:error, :path_not_found} = Grapple.find_path(node1, node2)
    end

    test "find_path/3 returns same node for identical source and target" do
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      
      assert {:ok, [^node1]} = Grapple.find_path(node1, node1)
    end
  end

  describe "query operations" do
    test "query/1 executes basic MATCH query" do
      {:ok, _node1} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
      {:ok, _node2} = Grapple.create_node(%{name: "Bob", role: "Manager"})
      
      assert {:ok, nodes} = Grapple.query("MATCH (n) RETURN n")
      assert length(nodes) >= 2
    end

    test "query/1 executes property-based MATCH query" do
      {:ok, _node1} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
      {:ok, _node2} = Grapple.create_node(%{name: "Bob", role: "Manager"})
      
      assert {:ok, engineers} = Grapple.query("MATCH (n {role: \"Engineer\"}) RETURN n")
      assert length(engineers) >= 1
      assert hd(engineers).properties.role == "Engineer"
    end

    test "query/1 returns error for unsupported queries" do
      assert {:error, {:parse_error, :unsupported_query}} = Grapple.query("INVALID QUERY")
    end
  end

  describe "performance" do
    test "node creation performance - should handle batch operations" do
      node_count = 1000
      
      {time_microseconds, _results} = :timer.tc(fn ->
        1..node_count
        |> Enum.map(fn i -> Grapple.create_node(%{id: i, name: "Node#{i}"}) end)
        |> Enum.all?(fn {:ok, _id} -> true end)
      end)
      
      # Should complete 1000 nodes in under 100ms (100,000 microseconds)
      assert time_microseconds < 100_000
      
      # Verify nodes were created
      stats = Grapple.get_stats()
      assert stats.total_nodes >= node_count
    end

    test "property lookup performance - should be O(1)" do
      # Create nodes with same property value
      property_count = 100
      1..property_count
      |> Enum.each(fn i -> 
        Grapple.create_node(%{category: "test", id: i}) 
      end)
      
      # Time the property lookup
      {time_microseconds, {:ok, results}} = :timer.tc(fn ->
        Grapple.find_nodes_by_property(:category, "test")
      end)
      
      # Should find all nodes quickly (under 10ms for 100 nodes)
      assert time_microseconds < 10_000
      assert length(results) == property_count
    end
  end
end
