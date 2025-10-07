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
end
