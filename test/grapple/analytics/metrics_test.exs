defmodule Grapple.Analytics.MetricsTest do
  use ExUnit.Case, async: false
  alias Grapple.Analytics.Metrics

  setup do
    # Clean state before each test
    Application.stop(:grapple)
    Application.start(:grapple)
    :ok
  end

  describe "graph_density/0" do
    test "returns 0 for empty graph" do
      assert {:ok, density} = Metrics.graph_density()
      assert density == 0.0
    end

    test "returns 0 for single node" do
      {:ok, _node1} = Grapple.create_node(%{name: "A"})

      assert {:ok, density} = Metrics.graph_density()
      assert density == 0.0
    end

    test "calculates density for sparse graph" do
      # 3 nodes, 1 edge out of 6 possible = 1/6 ≈ 0.167
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, _node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")

      assert {:ok, density} = Metrics.graph_density()
      assert_in_delta(density, 0.167, 0.01)
    end

    test "calculates density for complete graph" do
      # 3 nodes, all connected = 6/6 = 1.0
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node1, node3, "connects")
      Grapple.create_edge(node2, node1, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")
      Grapple.create_edge(node3, node2, "connects")

      assert {:ok, density} = Metrics.graph_density()
      assert density == 1.0
    end
  end

  describe "graph_diameter/0" do
    test "returns 0 for empty or single node graph" do
      {:ok, diameter} = Metrics.graph_diameter()
      assert diameter == 0

      {:ok, _node1} = Grapple.create_node(%{name: "A"})
      {:ok, diameter} = Metrics.graph_diameter()
      assert diameter == 0
    end

    test "calculates diameter for linear graph" do
      # Linear: 1 - 2 - 3 - 4, diameter = 3
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node4, "connects")

      assert {:ok, diameter} = Metrics.graph_diameter()
      assert diameter == 3
    end

    test "calculates diameter for star graph" do
      # Star: center connected to 3 nodes, diameter = 2
      {:ok, center} = Grapple.create_node(%{name: "Center"})
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(center, node1, "connects")
      Grapple.create_edge(center, node2, "connects")
      Grapple.create_edge(center, node3, "connects")

      assert {:ok, diameter} = Metrics.graph_diameter()
      assert diameter == 2
    end
  end

  describe "degree_distribution/0" do
    test "returns zeros for empty graph" do
      assert {:ok, stats} = Metrics.degree_distribution()
      assert stats.min == 0
      assert stats.max == 0
      assert stats.mean == 0.0
    end

    test "calculates distribution for uniform graph" do
      # All nodes have degree 2
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")
      Grapple.create_edge(node3, node1, "connects")

      assert {:ok, stats} = Metrics.degree_distribution()
      assert stats.min == 2
      assert stats.max == 2
      assert stats.mean == 2.0
      assert stats.median == 2.0
    end

    test "calculates distribution for varied graph" do
      # Star graph: center has degree 3, others have degree 1
      {:ok, center} = Grapple.create_node(%{name: "Center"})
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(center, node1, "connects")
      Grapple.create_edge(center, node2, "connects")
      Grapple.create_edge(center, node3, "connects")

      assert {:ok, stats} = Metrics.degree_distribution()
      assert stats.min == 1
      assert stats.max == 3
      # mean = (3 + 1 + 1 + 1) / 4 = 1.5
      assert stats.mean == 1.5
    end
  end

  describe "average_path_length/0" do
    test "returns 0 for single node" do
      {:ok, _node1} = Grapple.create_node(%{name: "A"})

      assert {:ok, avg} = Metrics.average_path_length()
      assert avg == 0.0
    end

    test "calculates average for linear graph" do
      # Linear: 1 - 2 - 3
      # Paths: 1->2=1, 1->3=2, 2->1=1, 2->3=1, 3->1=2, 3->2=1
      # Average = 8/6 ≈ 1.33
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, avg} = Metrics.average_path_length()
      assert avg > 0
      assert avg < 3
    end
  end

  describe "connectivity_metrics/0" do
    test "identifies connected graph" do
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      {:ok, node3} = Grapple.create_node(%{name: "C"})

      Grapple.create_edge(node1, node2, "connects")
      Grapple.create_edge(node2, node3, "connects")

      assert {:ok, metrics} = Metrics.connectivity_metrics()
      assert metrics.is_connected == true
      assert metrics.component_count == 1
      assert metrics.largest_component_size == 3
    end

    test "identifies disconnected components" do
      # Two separate components
      {:ok, node1} = Grapple.create_node(%{name: "A"})
      {:ok, node2} = Grapple.create_node(%{name: "B"})
      Grapple.create_edge(node1, node2, "connects")

      {:ok, node3} = Grapple.create_node(%{name: "C"})
      {:ok, node4} = Grapple.create_node(%{name: "D"})
      Grapple.create_edge(node3, node4, "connects")

      assert {:ok, metrics} = Metrics.connectivity_metrics()
      assert metrics.is_connected == false
      assert metrics.component_count == 2
      assert metrics.largest_component_size == 2
    end
  end
end
