defmodule Grapple.Analytics.CentralityTest do
  use ExUnit.Case, async: false
  alias Grapple.Analytics.Centrality

  setup do
    # Clean state before each test
    Application.stop(:grapple)
    Application.start(:grapple)
    :ok
  end

  describe "pagerank/1" do
    test "returns empty map for empty graph" do
      assert {:ok, ranks} = Centrality.pagerank()
      assert ranks == %{}
    end

    test "calculates pagerank for simple graph" do
      # Create a simple 3-node graph: 1 -> 2 -> 3
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "links_to")
      Grapple.create_edge(node2, node3, "links_to")

      assert {:ok, ranks} = Centrality.pagerank()
      assert map_size(ranks) == 3

      # All ranks should be positive
      assert Enum.all?(ranks, fn {_id, rank} -> rank > 0 end)

      # Sum of all ranks should be approximately 1
      total = ranks |> Map.values() |> Enum.sum()
      assert_in_delta(total, 1.0, 0.01)
    end

    test "gives higher rank to nodes with more incoming links" do
      # Create a star graph: 1,2,3 -> 4 (center)
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, center} = Grapple.create_node(%{name: "Center"})

      Grapple.create_edge(node1, center, "links_to")
      Grapple.create_edge(node2, center, "links_to")
      Grapple.create_edge(node3, center, "links_to")

      assert {:ok, ranks} = Centrality.pagerank()

      # Center should have highest rank
      center_rank = Map.get(ranks, center)
      assert center_rank > Map.get(ranks, node1)
      assert center_rank > Map.get(ranks, node2)
      assert center_rank > Map.get(ranks, node3)
    end

    test "accepts custom damping factor" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      Grapple.create_edge(node1, node2, "links_to")

      assert {:ok, ranks1} = Centrality.pagerank(damping_factor: 0.85)
      assert {:ok, ranks2} = Centrality.pagerank(damping_factor: 0.50)

      # Different damping factors should give different results
      refute ranks1 == ranks2
    end
  end

  describe "betweenness_centrality/0" do
    test "returns empty map for empty graph" do
      assert {:ok, betweenness} = Centrality.betweenness_centrality()
      assert betweenness == %{}
    end

    test "calculates betweenness for simple graph" do
      # Linear graph: 1 -> 2 -> 3
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, betweenness} = Centrality.betweenness_centrality()
      assert map_size(betweenness) == 3

      # Middle node should have highest betweenness
      assert Map.get(betweenness, node2) >= Map.get(betweenness, node1)
      assert Map.get(betweenness, node2) >= Map.get(betweenness, node3)
    end

    test "identifies bridge nodes" do
      # Create two clusters connected by a bridge node
      # Cluster 1: 1 - 2
      # Bridge: 2 - 3
      # Cluster 2: 3 - 4
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node4, "connects")

      assert {:ok, betweenness} = Centrality.betweenness_centrality()

      # Bridge nodes (2 and 3) should have higher betweenness
      bridge_bet_2 = Map.get(betweenness, node2)
      bridge_bet_3 = Map.get(betweenness, node3)

      assert bridge_bet_2 > 0
      assert bridge_bet_3 > 0
    end
  end

  describe "closeness_centrality/1" do
    test "returns 0 for single node graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})

      assert {:ok, closeness} = Centrality.closeness_centrality(node1)
      assert closeness == 0.0
    end

    test "calculates closeness for connected nodes" do
      # Triangle: 1 - 2 - 3 - 1
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, closeness1} = Centrality.closeness_centrality(node1)
      assert {:ok, closeness2} = Centrality.closeness_centrality(node2)
      assert {:ok, closeness3} = Centrality.closeness_centrality(node3)

      # All should have positive closeness
      assert closeness1 > 0
      assert closeness2 > 0
      assert closeness3 > 0

      # In a symmetric triangle, all should have similar closeness
      assert_in_delta(closeness1, closeness2, 0.1)
      assert_in_delta(closeness2, closeness3, 0.1)
    end

    test "returns error for non-existent node" do
      assert {:error, :node_not_found} = Centrality.closeness_centrality(99999)
    end
  end
end
