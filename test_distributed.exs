#!/usr/bin/env elixir

# Test script for minimal distributed functionality
Code.prepend_path("_build/dev/lib/grapple/ebin")
Application.start(:logger)

# Start with distributed mode enabled
Application.put_env(:grapple, :distributed, true)

# Start the application
{:ok, _} = Grapple.Application.start(nil, nil)

IO.puts("🌐 Testing Grapple Distributed Foundation")
IO.puts("=" |> String.duplicate(50))

# Test 1: Basic cluster functionality
IO.puts("\n📡 Test 1: Cluster Manager")

cluster_info = Grapple.Distributed.ClusterManager.get_cluster_info()
IO.puts("✅ Cluster initialized:")
IO.puts("   Local node: #{cluster_info.local_node}")
IO.puts("   Nodes: #{inspect(cluster_info.nodes)}")
IO.puts("   Partitions: #{cluster_info.partition_count}")

# Test 2: Auto-discovery
IO.puts("\n🔍 Test 2: Auto-discovery")

case Grapple.Distributed.Discovery.discover_peers() do
  {:ok, peers} ->
    IO.puts("✅ Discovery completed: #{length(peers)} peers found")
    if length(peers) > 0 do
      IO.puts("   Peers: #{inspect(peers)}")
    else
      IO.puts("   No peers found (normal for single node)")
    end
  
  {:error, reason} ->
    IO.puts("⚠️ Discovery failed: #{inspect(reason)}")
end

# Test 3: Health monitoring
IO.puts("\n🏥 Test 3: Health Monitor")

health = Grapple.Distributed.HealthMonitor.get_cluster_health()
IO.puts("✅ Health monitor active:")
IO.puts("   Status: #{health.overall_status}")
IO.puts("   Monitored nodes: #{length(health.monitored_nodes)}")
IO.puts("   Failed nodes: #{length(health.failed_nodes)}")

# Test 4: Data distribution
IO.puts("\n📊 Test 4: Data Distribution")

# Test key-to-node mapping
test_keys = ["user:1", "post:123", "comment:456", "user:999"]
for key <- test_keys do
  target_node = Grapple.Distributed.ClusterManager.get_node_for_key(key)
  IO.puts("   Key '#{key}' → #{target_node}")
end

# Test 5: Integration with existing graph operations
IO.puts("\n🔗 Test 5: Graph Operations Integration")

# Create some test data
{:ok, node1} = Grapple.create_node(%{name: "Alice", type: "user"})
{:ok, node2} = Grapple.create_node(%{name: "Bob", type: "user"})
{:ok, _edge} = Grapple.create_edge(node1, node2, "friends", %{})

IO.puts("✅ Created graph data in distributed environment")

# Show final statistics
stats = Grapple.get_stats()
IO.puts("   Nodes: #{stats.total_nodes}")
IO.puts("   Edges: #{stats.total_edges}")

# Test 6: Mnesia verification
IO.puts("\n💾 Test 6: Mnesia Integration")

case :mnesia.system_info(:is_running) do
  :yes ->
    IO.puts("✅ Mnesia running")
    
    # Check our tables exist
    tables = :mnesia.system_info(:tables)
    grapple_tables = Enum.filter(tables, fn table ->
      table in [:cluster_nodes, :data_partitions]
    end)
    
    IO.puts("   Grapple tables: #{inspect(grapple_tables)}")
    
    # Show cluster nodes in Mnesia
    case :mnesia.transaction(fn -> :mnesia.all_keys(:cluster_nodes) end) do
      {:atomic, node_keys} ->
        IO.puts("   Registered nodes: #{inspect(node_keys)}")
      
      {:aborted, reason} ->
        IO.puts("   ⚠️ Could not read cluster nodes: #{inspect(reason)}")
    end
    
  status ->
    IO.puts("⚠️ Mnesia status: #{status}")
end

IO.puts("\n🎉 Distributed foundation testing complete!")
IO.puts("\n💡 Next steps:")
IO.puts("   - Test multi-node deployment with: GRAPPLE_CLUSTER_NODES=node1,node2")
IO.puts("   - Enable UDP discovery on local network")
IO.puts("   - Try simulated node failures")
IO.puts("   - Implement data replication")

IO.puts("\n🔧 To test multi-node locally:")
IO.puts("   # Terminal 1:")
IO.puts("   iex --name grapple1@localhost --cookie grapple_cluster -S mix")
IO.puts("   Application.put_env(:grapple, :distributed, true)")
IO.puts("   ")
IO.puts("   # Terminal 2:")  
IO.puts("   iex --name grapple2@localhost --cookie grapple_cluster -S mix")
IO.puts("   Application.put_env(:grapple, :distributed, true)")
IO.puts("   Grapple.Distributed.ClusterManager.join_cluster(:'grapple1@localhost')")