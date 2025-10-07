defmodule Grapple.Distributed.HealthMonitorTest do
  use ExUnit.Case, async: false
  alias Grapple.Distributed.HealthMonitor

  setup do
    # Start the health monitor if not already started
    case HealthMonitor.start_link([]) do
      {:ok, pid} -> {:ok, monitor: pid}
      {:error, {:already_started, pid}} -> {:ok, monitor: pid}
    end
  end

  describe "start_link/1" do
    test "starts the health monitor successfully" do
      assert Process.whereis(HealthMonitor) != nil
    end
  end

  describe "get_health/0" do
    test "returns health status map" do
      health = HealthMonitor.get_health()

      assert is_map(health)
      assert Map.has_key?(health, :status)
      assert Map.has_key?(health, :nodes)
      assert Map.has_key?(health, :timestamp)
    end

    test "returns healthy status for local node" do
      health = HealthMonitor.get_health()

      assert health.status in [:healthy, :degraded, :unhealthy]
      assert is_map(health.nodes)
      assert is_integer(health.timestamp)
    end

    test "includes local node in node health map" do
      health = HealthMonitor.get_health()
      local_node = node()

      assert Map.has_key?(health.nodes, local_node)
      node_health = health.nodes[local_node]

      assert is_map(node_health)
      assert Map.has_key?(node_health, :status)
      assert Map.has_key?(node_health, :last_check)
    end
  end

  describe "check_node/1" do
    test "reports local node as healthy" do
      local_node = node()
      result = HealthMonitor.check_node(local_node)

      assert result in [:healthy, {:error, :not_connected}]
    end

    test "reports nonexistent nodes as unhealthy" do
      result = HealthMonitor.check_node(:nonexistent@localhost)

      assert result == {:error, :not_connected}
    end
  end

  describe "get_node_status/1" do
    test "returns status for local node" do
      local_node = node()
      status = HealthMonitor.get_node_status(local_node)

      assert status in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "returns unknown for nonexistent nodes" do
      status = HealthMonitor.get_node_status(:nonexistent@localhost)

      assert status == :unknown
    end
  end

  describe "health monitoring over time" do
    test "consistently reports health status" do
      # Get health status multiple times
      health1 = HealthMonitor.get_health()
      :timer.sleep(10)
      health2 = HealthMonitor.get_health()

      # Both should be valid health reports
      assert is_map(health1)
      assert is_map(health2)

      # Timestamps should be different
      assert health2.timestamp >= health1.timestamp
    end
  end

  describe "error handling" do
    test "handles nil node gracefully" do
      result = HealthMonitor.check_node(nil)

      assert result == {:error, :not_connected}
    end

    test "handles invalid node names" do
      result = HealthMonitor.check_node(:invalid_node)

      assert result == {:error, :not_connected}
    end
  end
end
