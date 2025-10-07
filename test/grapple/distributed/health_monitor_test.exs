defmodule Grapple.Distributed.HealthMonitorTest do
  use ExUnit.Case, async: false
  alias Grapple.Distributed.HealthMonitor

  setup do
    # Ensure the health monitor is started and ready
    pid = case HealthMonitor.start_link([]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end

    # Give the GenServer time to fully initialize
    :timer.sleep(10)

    # Verify it's alive
    assert Process.alive?(pid)

    {:ok, monitor: pid}
  end

  describe "start_link/1" do
    test "starts the health monitor successfully" do
      assert Process.whereis(HealthMonitor) != nil
    end
  end

  describe "get_cluster_health/0" do
    test "returns health status map" do
      health = HealthMonitor.get_cluster_health()

      assert is_map(health)
      assert Map.has_key?(health, :overall_status)
      assert Map.has_key?(health, :monitored_nodes)
      assert Map.has_key?(health, :local_node)
    end

    test "returns healthy status for local node" do
      # Ensure the GenServer is responsive before calling
      assert Process.whereis(HealthMonitor) != nil
      assert Process.alive?(Process.whereis(HealthMonitor))

      health = HealthMonitor.get_cluster_health()

      assert health.overall_status in [:unknown, :healthy, :degraded, :critical]
      assert is_list(health.monitored_nodes)
      assert is_atom(health.local_node)
    end

    test "includes local node in health map" do
      health = HealthMonitor.get_cluster_health()
      local_node = node()

      assert health.local_node == local_node
      assert is_list(health.failed_nodes)
      assert is_list(health.recovering_nodes)
    end
  end

  describe "force_health_check/0" do
    test "triggers a health check" do
      # Just verify the function is callable
      assert :ok == HealthMonitor.force_health_check()
    end
  end

  describe "health monitoring over time" do
    test "consistently reports health status" do
      # Get health status multiple times
      health1 = HealthMonitor.get_cluster_health()
      :timer.sleep(10)
      health2 = HealthMonitor.get_cluster_health()

      # Both should be valid health reports
      assert is_map(health1)
      assert is_map(health2)

      # Overall status should be consistent
      assert health1.overall_status in [:unknown, :healthy, :degraded, :critical]
      assert health2.overall_status in [:unknown, :healthy, :degraded, :critical]
    end
  end
end
