defmodule Grapple.Distributed.ClusterManagerTest do
  use ExUnit.Case, async: false
  alias Grapple.Distributed.ClusterManager

  setup do
    # Start the cluster manager if not already started
    case ClusterManager.start_link([]) do
      {:ok, pid} -> {:ok, manager: pid}
      {:error, {:already_started, pid}} -> {:ok, manager: pid}
    end
  end

  describe "start_link/1" do
    test "starts the cluster manager successfully" do
      # Already started in setup
      assert Process.whereis(ClusterManager) != nil
    end
  end

  describe "join_cluster/1" do
    test "returns connection_failed for nonexistent nodes" do
      result = ClusterManager.join_cluster(:nonexistent@localhost)
      assert result == {:error, :connection_failed}
    end

    test "handles already connected nodes" do
      # Try connecting to self (already connected)
      local_node = node()

      result = ClusterManager.join_cluster(local_node)
      # Should either succeed (already connected) or return error
      assert result in [{:ok, :connected}, {:error, :connection_failed}]
    end

    test "validates node name format" do
      result = ClusterManager.join_cluster(:invalid_node_name)
      assert result == {:error, :connection_failed}
    end
  end

  describe "get_cluster_info/0" do
    test "returns cluster information map" do
      info = ClusterManager.get_cluster_info()

      assert is_map(info)
      assert Map.has_key?(info, :local_node)
      assert Map.has_key?(info, :nodes)
      assert Map.has_key?(info, :partitions)
    end

    test "returns correct local node information" do
      info = ClusterManager.get_cluster_info()

      assert info.local_node == node()
      assert is_list(info.nodes)
      assert is_integer(info.partitions)
      assert info.partitions > 0
    end

    test "includes local node in node list" do
      info = ClusterManager.get_cluster_info()

      assert node() in info.nodes
    end
  end

  describe "get_cluster_status/0" do
    test "returns status map" do
      status = ClusterManager.get_cluster_status()

      assert is_map(status)
      assert Map.has_key?(status, :healthy)
      assert Map.has_key?(status, :node_count)
      assert Map.has_key?(status, :connected_nodes)
    end

    test "reports healthy status for single node" do
      status = ClusterManager.get_cluster_status()

      assert status.healthy == true
      assert status.node_count >= 1
      assert is_list(status.connected_nodes)
    end
  end

  describe "distributed mode detection" do
    test "detects distributed mode based on application config" do
      info = ClusterManager.get_cluster_info()

      # Should have valid cluster info regardless of mode
      assert is_map(info)
      assert info.local_node == node()
    end
  end

  describe "error handling" do
    test "handles invalid join requests gracefully" do
      result = ClusterManager.join_cluster(nil)
      assert result == {:error, :connection_failed}
    end

    test "handles empty node names" do
      result = ClusterManager.join_cluster(:"")
      assert result == {:error, :connection_failed}
    end
  end
end
