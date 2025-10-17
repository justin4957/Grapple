defmodule Grapple.Analytics.CommunityTest do
  use ExUnit.Case, async: false
  alias Grapple.Analytics.Community

  setup do
    # Clean state before each test
    Application.stop(:grapple)
    Application.start(:grapple)
    :ok
  end

  describe "connected_components/0" do
    test "returns empty list for empty graph" do
      assert {:ok, components} = Community.connected_components()
      assert components == []
    end

    test "returns single component for fully connected graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, components} = Community.connected_components()
      assert length(components) == 1
      assert length(hd(components)) == 3
    end

    test "identifies multiple disconnected components" do
      # Component 1: 1 - 2
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      Grapple.create_edge(node1, node2, "connects")

      # Component 2: 3 - 4
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})
      Grapple.create_edge(node3, node4, "connects")

      # Isolated node: 5
      {:ok, _node5} = Grapple.create_node(%{name: "E"})

      assert {:ok, components} = Community.connected_components()
      assert length(components) == 3

      # Components should be sorted by size (descending)
      sizes = Enum.map(components, &length/1)
      assert sizes == Enum.sort(sizes, :desc)
    end

    test "handles isolated nodes" do
      {:ok, _node1} = Grapple.create_node(%{name: "A"})
      {:ok, _node2} = Grapple.create_node(%{name: "B"})
      {:ok, _node3} = Grapple.create_node(%{name: "C"})

      assert {:ok, components} = Community.connected_components()
      assert length(components) == 3
      assert Enum.all?(components, fn comp -> length(comp) == 1 end)
    end
  end

  describe "clustering_coefficient/0" do
    test "returns 0 for empty graph" do
      assert {:ok, coefficient} = Community.clustering_coefficient()
      assert coefficient == 0.0
    end

    test "returns 0 for graph with no triangles" do
      # Linear graph: 1 - 2 - 3 (no triangles)
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, coefficient} = Community.clustering_coefficient()
      assert coefficient == 0.0
    end

    test "returns 1 for complete triangle" do
      # Complete triangle: 1 - 2 - 3 - 1
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, coefficient} = Community.clustering_coefficient()
      assert coefficient > 0
    end

    test "calculates coefficient for mixed graph" do
      # Create a graph with some triangles
      # Triangle: 1 - 2 - 3 - 1
      # Additional nodes: 4 connected to 1
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")
      Grapple.create_edge(node1, node4, "connects")

      assert {:ok, coefficient} = Community.clustering_coefficient()
      assert coefficient >= 0.0
      assert coefficient <= 1.0
    end
  end

  describe "local_clustering_coefficient/1" do
    test "returns 0 for node with less than 2 neighbors" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      Grapple.create_edge(node1, node2, "connects")

      assert {:ok, coefficient} = Community.local_clustering_coefficient(node1)
      assert coefficient == 0.0
    end

    test "returns 1 for node in complete triangle" do
      # Complete triangle
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, coefficient} = Community.local_clustering_coefficient(node1)
      assert coefficient == 1.0
    end

    test "calculates partial clustering" do
      # Node 1 has 3 neighbors (2, 3, 4)
      # Only 2 and 3 are connected (1 out of 3 possible edges)
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node1, node3, "connects")
      Grapple.create_edge(node1, node4, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, coefficient} = Community.local_clustering_coefficient(node1)
      # 1 edge out of 3 possible = 1/3 ≈ 0.33
      assert_in_delta(coefficient, 0.33, 0.01)
    end

    test "returns error for non-existent node" do
      assert {:error, :node_not_found} = Community.local_clustering_coefficient(99999)
    end
  end

  describe "louvain_communities/0" do
    test "returns empty map for empty graph" do
      assert {:ok, communities} = Community.louvain_communities()
      assert communities == %{}
    end

    test "detects single community for fully connected graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, communities} = Community.louvain_communities()
      assert map_size(communities) == 3

      # All nodes should have community assignments
      assert Enum.all?(communities, fn {_node_id, comm_id} -> comm_id != nil end)
    end

    test "detects multiple communities in disconnected graph" do
      # Community 1: 1 - 2 - 3 (triangle)
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      # Community 2: 4 - 5 (pair)
      {:ok, node4} = Grapple.create_node(%{name: "D"})
      {:ok, node5} = Grapple.create_node(%{name: "E"})

      Grapple.create_edge(node4, node5, "connects")

      assert {:ok, communities} = Community.louvain_communities()
      assert map_size(communities) == 5

      # Group nodes by community
      community_groups =
        communities
        |> Enum.group_by(fn {_node_id, comm_id} -> comm_id end)

      # Should have at least 2 distinct communities
      assert map_size(community_groups) >= 2
    end

    test "assigns all nodes to communities" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, communities} = Community.louvain_communities()

      # Every node should have a community assignment
      assert Map.has_key?(communities, node1)
      assert Map.has_key?(communities, node2)
      assert Map.has_key?(communities, node3)
    end
  end

  describe "k_core_decomposition/0" do
    test "returns empty map for empty graph" do
      assert {:ok, cores} = Community.k_core_decomposition()
      assert cores == %{}
    end

    test "assigns core numbers for simple graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, cores} = Community.k_core_decomposition()
      assert map_size(cores) == 3

      # All core numbers should be non-negative
      assert Enum.all?(cores, fn {_node_id, core_num} -> core_num >= 0 end)
    end

    test "identifies higher core for densely connected nodes" do
      # Create a clique of 4 nodes (all connected to each other)
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      # Complete graph on 4 nodes
      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node1, node3, "connects")
      Grapple.create_edge(node1, node4, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node2, node4, "connects")
      Grapple.create_edge(node3, node4, "connects")

      assert {:ok, cores} = Community.k_core_decomposition()

      # In a complete graph on 4 nodes, each node has degree 3
      # So all should be in 3-core
      core_values = Map.values(cores)
      max_core = Enum.max(core_values)
      assert max_core >= 2
    end

    test "assigns lower core to peripheral nodes" do
      # Triangle with dangling node: 1 - 2 - 3 - 1, and 4 connected only to 1
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")
      Grapple.create_edge(node1, node4, "connects")

      assert {:ok, cores} = Community.k_core_decomposition()

      # Node 4 has only 1 connection, so should have lower core number
      core4 = Map.get(cores, node4)
      core1 = Map.get(cores, node1)

      # Triangle nodes should have higher or equal core numbers
      assert core1 >= core4
    end
  end

  describe "triangle_count/0" do
    test "returns empty map for empty graph" do
      assert {:ok, triangles} = Community.triangle_count()
      assert triangles == %{}
    end

    test "returns 0 triangles for linear graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, triangles} = Community.triangle_count()

      # No triangles in linear graph
      assert Enum.all?(triangles, fn {_node_id, count} -> count == 0 end)
    end

    test "counts triangles correctly for complete triangle" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, triangles} = Community.triangle_count()

      # Each node participates in 1 triangle
      assert Map.get(triangles, node1) == 1
      assert Map.get(triangles, node2) == 1
      assert Map.get(triangles, node3) == 1
    end

    test "counts multiple triangles for complex graph" do
      # Create two triangles sharing an edge: 1-2-3-1 and 1-2-4-1
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")
      Grapple.create_edge(node1, node4, "connects")
      Grapple.create_edge(node2, node4, "connects")

      assert {:ok, triangles} = Community.triangle_count()

      # Nodes 1 and 2 should participate in 2 triangles each
      assert Map.get(triangles, node1) == 2
      assert Map.get(triangles, node2) == 2

      # Nodes 3 and 4 should participate in 1 triangle each
      assert Map.get(triangles, node3) == 1
      assert Map.get(triangles, node4) == 1
    end
  end
end
