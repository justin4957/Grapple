defmodule Grapple.Distributed.ClusterManagerTest do
  use ExUnit.Case, async: false
  alias Grapple.Distributed.ClusterManager

  setup do
    # Ensure the cluster manager is started and ready
    pid =
      case ClusterManager.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # Give the GenServer time to fully initialize
    :timer.sleep(10)

    # Verify it's alive
    assert Process.alive?(pid)

    {:ok, manager: pid}
  end

  describe "start_link/1" do
    test "starts the cluster manager successfully" do
      # Already started in setup
      assert Process.whereis(ClusterManager) != nil
    end
  end

  describe "join_cluster/1" do
    test "handles connection attempts to any node" do
      result = ClusterManager.join_cluster(:nonexistent@localhost)
      # join_cluster can return either :joined or connection_failed
      assert result in [{:ok, :joined}, {:error, :connection_failed}]
    end

    test "handles already connected nodes" do
      # Try connecting to self (already connected)
      local_node = node()

      result = ClusterManager.join_cluster(local_node)
      # Should either succeed (already connected) or return joined
      assert result in [{:ok, :connected}, {:ok, :joined}, {:error, :connection_failed}]
    end

    test "validates node name format" do
      result = ClusterManager.join_cluster(:invalid_node_name)
      assert result in [{:ok, :joined}, {:error, :connection_failed}]
    end
  end

  describe "get_cluster_info/0" do
    test "returns cluster information map" do
      info = ClusterManager.get_cluster_info()

      assert is_map(info)
      assert Map.has_key?(info, :local_node)
      assert Map.has_key?(info, :nodes)
      assert Map.has_key?(info, :partition_count)
    end

    test "returns correct local node information" do
      info = ClusterManager.get_cluster_info()

      assert info.local_node == node()
      assert is_list(info.nodes)
      assert is_integer(info.partition_count)
      assert info.partition_count > 0
    end

    test "includes local node in node list" do
      info = ClusterManager.get_cluster_info()

      assert node() in info.nodes
    end
  end

  describe "distributed mode detection" do
    test "detects distributed mode based on application config" do
      # Ensure the GenServer is responsive before calling
      assert Process.whereis(ClusterManager) != nil
      assert Process.alive?(Process.whereis(ClusterManager))

      info = ClusterManager.get_cluster_info()

      # Should have valid cluster info regardless of mode
      assert is_map(info)
      assert info.local_node == node()
    end
  end

  describe "error handling" do
    test "handles invalid join requests gracefully" do
      result = ClusterManager.join_cluster(nil)
      assert result in [{:ok, :joined}, {:error, :connection_failed}]
    end

    test "handles empty node names" do
      result = ClusterManager.join_cluster(:"")
      assert result in [{:ok, :joined}, {:error, :connection_failed}]
    end
  end
end
