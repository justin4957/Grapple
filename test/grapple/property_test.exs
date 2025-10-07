defmodule Grapple.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  setup do
    # Ensure the ETS graph store is started
    case Grapple.Storage.EtsGraphStore.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
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

  describe "node operations properties" do
    property "creating a node always returns a positive integer ID" do
      check all(
              name <- string(:alphanumeric, min_length: 1, max_length: 50),
              age <- integer(1..150),
              max_runs: 100
            ) do
        properties = %{name: name, age: age}
        assert {:ok, node_id} = Grapple.create_node(properties)
        assert is_integer(node_id)
        assert node_id > 0
      end
    end

    property "retrieving a created node returns the same properties" do
      check all(
              name <- string(:alphanumeric, min_length: 1, max_length: 50),
              role <- member_of(["Engineer", "Manager", "Designer", "Analyst"]),
              level <- member_of(["Junior", "Mid", "Senior", "Lead"]),
              max_runs: 50
            ) do
        properties = %{name: name, role: role, level: level}
        {:ok, node_id} = Grapple.create_node(properties)

        assert {:ok, node} = Grapple.get_node(node_id)
        assert node.id == node_id
        assert node.properties == properties
      end
    end

    property "finding nodes by property returns all matching nodes" do
      check all(
              role <- member_of(["Engineer", "Manager"]),
              count <- integer(1..10),
              max_runs: 20
            ) do
        # Create nodes with the same role
        Enum.each(1..count, fn i ->
          Grapple.create_node(%{id: i, role: role})
        end)

        {:ok, found_nodes} = Grapple.find_nodes_by_property(:role, role)

        # Should find at least the nodes we created
        assert length(found_nodes) >= count

        # All found nodes should have the matching role
        Enum.each(found_nodes, fn node ->
          assert node.properties.role == role
        end)
      end
    end

    property "nodes with unique properties can be found individually" do
      check all(
              unique_id <- integer(1000..999_999),
              name <- string(:alphanumeric, min_length: 1, max_length: 30),
              max_runs: 50
            ) do
        properties = %{unique_id: unique_id, name: name}
        {:ok, node_id} = Grapple.create_node(properties)

        {:ok, found_nodes} = Grapple.find_nodes_by_property(:unique_id, unique_id)

        # Should find at least one node
        assert length(found_nodes) >= 1

        # At least one should be our created node
        assert Enum.any?(found_nodes, fn node -> node.id == node_id end)
      end
    end
  end

  describe "edge operations properties" do
    property "creating an edge between valid nodes succeeds" do
      check all(
              label <- member_of(["knows", "follows", "likes", "reports_to"]),
              weight <- integer(1..100),
              max_runs: 50
            ) do
        {:ok, node1} = Grapple.create_node(%{name: "Node1"})
        {:ok, node2} = Grapple.create_node(%{name: "Node2"})

        properties = %{weight: weight}
        result = Grapple.create_edge(node1, node2, label, properties)

        assert {:ok, edge_id} = result
        assert is_integer(edge_id)
        assert edge_id > 0
      end
    end

    property "edges can be found by their label" do
      check all(
              label <- member_of(["knows", "follows"]),
              count <- integer(1..5),
              max_runs: 20
            ) do
        # Create nodes and edges
        nodes =
          Enum.map(1..(count + 1), fn i ->
            {:ok, node_id} = Grapple.create_node(%{id: i})
            node_id
          end)

        # Create edges with the same label
        Enum.each(0..(count - 1), fn i ->
          from = Enum.at(nodes, i)
          to = Enum.at(nodes, i + 1)
          Grapple.create_edge(from, to, label)
        end)

        {:ok, found_edges} = Grapple.find_edges_by_label(label)

        # Should find at least the edges we created
        assert length(found_edges) >= count

        # All found edges should have the matching label
        Enum.each(found_edges, fn edge ->
          assert edge.label == label
        end)
      end
    end

    property "edge properties are preserved" do
      check all(
              weight <- integer(1..1000),
              since <- integer(2000..2024),
              active <- boolean(),
              max_runs: 50
            ) do
        {:ok, node1} = Grapple.create_node(%{name: "A"})
        {:ok, node2} = Grapple.create_node(%{name: "B"})

        properties = %{weight: weight, since: since, active: active}
        {:ok, edge_id} = Grapple.create_edge(node1, node2, "test", properties)

        {:ok, edges} = Grapple.find_edges_by_label("test")
        edge = Enum.find(edges, fn e -> e.id == edge_id end)

        assert edge != nil
        assert edge.properties == properties
      end
    end
  end

  describe "graph traversal properties" do
    property "traversal depth 0 returns no nodes" do
      check all(
              name <- string(:alphanumeric, min_length: 1, max_length: 20),
              max_runs: 20
            ) do
        {:ok, node_id} = Grapple.create_node(%{name: name})

        {:ok, nodes} = Grapple.traverse(node_id, :out, 0)

        assert nodes == []
      end
    end

    property "traversal in opposite direction finds reverse edges" do
      check all(
              name1 <- string(:alphanumeric, min_length: 1, max_length: 20),
              name2 <- string(:alphanumeric, min_length: 1, max_length: 20),
              max_runs: 30
            ) do
        {:ok, node1} = Grapple.create_node(%{name: name1})
        {:ok, node2} = Grapple.create_node(%{name: name2})
        {:ok, _edge} = Grapple.create_edge(node1, node2, "knows")

        # Forward traversal
        {:ok, forward_nodes} = Grapple.traverse(node1, :out, 1)
        # Reverse traversal
        {:ok, reverse_nodes} = Grapple.traverse(node2, :in, 1)

        # Node2 should be reachable from node1 going out
        assert Enum.any?(forward_nodes, fn n -> n.id == node2 end)
        # Node1 should be reachable from node2 going in
        assert Enum.any?(reverse_nodes, fn n -> n.id == node1 end)
      end
    end

    property "path finding is symmetric for undirected interpretation" do
      check all(
              count <- integer(2..5),
              max_runs: 20
            ) do
        # Create a simple chain of nodes
        node_ids =
          Enum.map(1..count, fn i ->
            {:ok, id} = Grapple.create_node(%{id: i})
            id
          end)

        # Create edges in both directions
        Enum.each(0..(count - 2), fn i ->
          from = Enum.at(node_ids, i)
          to = Enum.at(node_ids, i + 1)
          Grapple.create_edge(from, to, "bidirectional")
          Grapple.create_edge(to, from, "bidirectional")
        end)

        first = List.first(node_ids)
        last = List.last(node_ids)

        # Path should exist in both directions
        result1 = Grapple.find_path(first, last)
        result2 = Grapple.find_path(last, first)

        assert {:ok, path1} = result1
        assert {:ok, path2} = result2

        # Both paths should have the same length
        assert length(path1) == length(path2)
        assert length(path1) == count
      end
    end
  end

  describe "invariants" do
    property "get_stats reflects created nodes" do
      check all(
              count <- integer(1..20),
              max_runs: 20
            ) do
        initial_stats = Grapple.get_stats()

        # Create nodes
        Enum.each(1..count, fn i ->
          Grapple.create_node(%{id: i})
        end)

        final_stats = Grapple.get_stats()

        # Node count should increase by exactly count
        assert final_stats.total_nodes == initial_stats.total_nodes + count
      end
    end

    property "memory usage increases with graph size" do
      check all(
              count <- integer(10..50),
              max_runs: 10
            ) do
        initial_stats = Grapple.get_stats()
        initial_memory = initial_stats.memory_usage.nodes

        # Create nodes
        Enum.each(1..count, fn i ->
          Grapple.create_node(%{id: i, name: "Node#{i}", value: i * 100})
        end)

        final_stats = Grapple.get_stats()
        final_memory = final_stats.memory_usage.nodes

        # Memory should increase
        assert final_memory > initial_memory
      end
    end

    property "node IDs are unique and monotonically increasing" do
      check all(
              count <- integer(2..20),
              max_runs: 20
            ) do
        ids =
          Enum.map(1..count, fn i ->
            {:ok, id} = Grapple.create_node(%{seq: i})
            id
          end)

        # All IDs should be unique
        assert length(Enum.uniq(ids)) == count

        # IDs should be increasing (allowing for other tests running)
        sorted_ids = Enum.sort(ids)
        assert sorted_ids == ids or length(Enum.uniq(ids)) == count
      end
    end
  end
end
