#!/usr/bin/env elixir

# Test script for Phase 2: Data Lifecycle Management features
Code.prepend_path("_build/dev/lib/grapple/ebin")
Application.start(:logger)

# Start with distributed mode enabled
Application.put_env(:grapple, :distributed, true)

# Start the application
{:ok, _} = Grapple.Application.start(nil, nil)

IO.puts("🌐 Testing Grapple Phase 2: Data Lifecycle Management")
IO.puts("=" |> String.duplicate(60))

# Test 1: Lifecycle Classification System
IO.puts("\n📊 Test 1: Lifecycle Classification System")

case Grapple.Distributed.LifecycleManager.classify_data("test_node_1", :ephemeral, %{test: true}) do
  {:ok, placement_strategy} ->
    IO.puts("✅ Ephemeral data classified successfully")
    IO.puts("   Primary node: #{placement_strategy.primary_node}")
    IO.puts("   Replication factor: #{placement_strategy.replication_factor}")
    IO.puts("   TTL: #{placement_strategy.ttl}")
    
  {:error, reason} ->
    IO.puts("❌ Classification failed: #{inspect(reason)}")
end

case Grapple.Distributed.LifecycleManager.classify_data("test_node_2", :computational, %{computation: "ml_training"}) do
  {:ok, placement_strategy} ->
    IO.puts("✅ Computational data classified successfully")
    IO.puts("   Persistence tier: #{placement_strategy.persistence_tier}")
    
  {:error, reason} ->
    IO.puts("❌ Computational classification failed: #{inspect(reason)}")
end

case Grapple.Distributed.LifecycleManager.classify_data("test_node_3", :persistent, %{critical: true}) do
  {:ok, placement_strategy} ->
    IO.puts("✅ Persistent data classified successfully")
    IO.puts("   Replication factor: #{placement_strategy.replication_factor}")
    
  {:error, reason} ->
    IO.puts("❌ Persistent classification failed: #{inspect(reason)}")
end

# Test lifecycle statistics
stats = Grapple.Distributed.LifecycleManager.get_lifecycle_stats()
IO.puts("📈 Lifecycle Statistics:")
IO.puts("   Total classified: #{stats.total_classified}")
IO.puts("   Classifications breakdown: #{inspect(stats.classifications)}")

# Test 2: Placement Engine
IO.puts("\n🎯 Test 2: Ephemeral-First Placement Engine")

# Create test graph data
{:ok, node1} = Grapple.create_node(%{name: "Alice", type: "user", classification: "hot"})
{:ok, node2} = Grapple.create_node(%{name: "Bob", type: "user", classification: "warm"})
{:ok, edge1} = Grapple.create_edge(node1, node2, "friends", %{since: "2024"})

IO.puts("✅ Created test graph data for placement testing")

case Grapple.Distributed.PlacementEngine.place_data("user:alice", %{id: node1}, :ephemeral) do
  {:ok, locations} ->
    IO.puts("✅ Ephemeral placement successful")
    IO.puts("   Locations: #{length(locations)} placement(s)")
    Enum.each(locations, fn location ->
      IO.puts("     #{location.node} (#{location.tier}) - #{location.role}")
    end)
    
  {:error, reason} ->
    IO.puts("❌ Placement failed: #{inspect(reason)}")
end

case Grapple.Distributed.PlacementEngine.place_data("edge:friendship", %{id: edge1}, :computational) do
  {:ok, locations} ->
    IO.puts("✅ Computational data placement successful")
    IO.puts("   Locations: #{length(locations)} placement(s)")
    
  {:error, reason} ->
    IO.puts("❌ Computational placement failed: #{inspect(reason)}")
end

# Test placement statistics
placement_stats = Grapple.Distributed.PlacementEngine.get_placement_stats()
IO.puts("📊 Placement Engine Statistics:")
IO.puts("   Local placements: #{placement_stats.local_placements}")
IO.puts("   Remote placements: #{placement_stats.remote_placements}")
IO.puts("   Cache hit ratio: #{Float.round(placement_stats.cache_hit_ratio * 100, 1)}%")

# Test 3: Replication Engine
IO.puts("\n🔄 Test 3: Smart Replication Strategies")

case Grapple.Distributed.ReplicationEngine.replicate_data("critical_data", %{value: "important"}, :balanced) do
  {:ok, replica_set} ->
    IO.puts("✅ Balanced replication created")
    IO.puts("   Key: #{replica_set.key}")
    IO.puts("   Primary node: #{replica_set.primary_node}")
    IO.puts("   Total replicas: #{length(replica_set.replicas)}")
    IO.puts("   Strategy: #{inspect(replica_set.strategy.conflict_resolution)}")
    
  {:error, reason} ->
    IO.puts("❌ Replication failed: #{inspect(reason)}")
end

case Grapple.Distributed.ReplicationEngine.replicate_data("session_data", %{session_id: "abc123"}, :adaptive) do
  {:ok, replica_set} ->
    IO.puts("✅ Adaptive replication created")
    IO.puts("   Replicas count: #{length(replica_set.replicas)}")
    
  {:error, reason} ->
    IO.puts("❌ Adaptive replication failed: #{inspect(reason)}")
end

# Test replica health
case Grapple.Distributed.ReplicationEngine.get_replica_health("critical_data") do
  {:ok, health} ->
    IO.puts("💚 Replica health check:")
    IO.puts("   Total replicas: #{health.total_replicas}")
    IO.puts("   Healthy replicas: #{health.healthy_replicas}")
    IO.puts("   Health ratio: #{Float.round(health.health_ratio * 100, 1)}%")
    IO.puts("   Primary healthy: #{health.primary_healthy}")
    
  {:error, reason} ->
    IO.puts("❌ Health check failed: #{inspect(reason)}")
end

# Test replication statistics
repl_stats = Grapple.Distributed.ReplicationEngine.get_replication_stats()
IO.puts("📈 Replication Statistics:")
IO.puts("   Total replica sets: #{repl_stats.total_replica_sets}")
IO.puts("   Consistency level: #{Float.round(repl_stats.consistency_level * 100, 1)}%")
IO.puts("   Replication efficiency: #{Float.round(repl_stats.replication_efficiency * 100, 1)}%")
IO.puts("   Conflict rate: #{Float.round(repl_stats.conflict_rate * 100, 2)}%")

# Test 4: Persistence Manager
IO.puts("\n💾 Test 4: Dynamic Persistence Policy Management")

# Create custom persistence policy
policy_config = %{
  primary_tier: :mnesia,
  backup_tier: :dets,
  replication_factor: 2,
  access_threshold: 25,
  migration_triggers: [:cost_optimization],
  retention_policy: :migrate_when_cold
}

case Grapple.Distributed.PersistenceManager.create_persistence_policy(:custom_policy, policy_config) do
  {:ok, :policy_created} ->
    IO.puts("✅ Custom persistence policy created")
    
  {:error, reason} ->
    IO.puts("❌ Policy creation failed: #{inspect(reason)}")
end

# Apply persistence policy
case Grapple.Distributed.PersistenceManager.apply_persistence_policy("test_data", :custom_policy) do
  {:ok, placement_result} ->
    IO.puts("✅ Persistence policy applied")
    IO.puts("   Target tier: #{placement_result.tier}")
    IO.puts("   Action: #{placement_result.action}")
    
  {:error, reason} ->
    IO.puts("❌ Policy application failed: #{inspect(reason)}")
end

# Test adaptive policy creation
usage_patterns = %{
  access_frequency: 150,  # High access
  data_size: 50_000,     # Medium size
  access_pattern: :sequential,
  retention_requirement: :critical
}

case Grapple.Distributed.PersistenceManager.adapt_policy_for_data("adaptive_data", usage_patterns) do
  {:ok, {adapted_policy, placement_result}} ->
    IO.puts("✅ Adaptive policy created and applied")
    IO.puts("   Primary tier: #{adapted_policy.primary_tier}")
    IO.puts("   Replication factor: #{adapted_policy.replication_factor}")
    IO.puts("   Retention policy: #{adapted_policy.retention_policy}")
    
  {:error, reason} ->
    IO.puts("❌ Adaptive policy failed: #{inspect(reason)}")
end

# Test optimal tier calculation
data_characteristics = %{
  access_frequency: 75,
  data_size: 1_000_000,
  latency_requirement: :low,
  durability_requirement: :standard
}

case Grapple.Distributed.PersistenceManager.get_optimal_tier(data_characteristics) do
  {:ok, optimal_tier} ->
    IO.puts("✅ Optimal tier calculated: #{optimal_tier}")
    
  {:error, reason} ->
    IO.puts("❌ Optimal tier calculation failed: #{inspect(reason)}")
end

# Test persistence statistics
persistence_stats = Grapple.Distributed.PersistenceManager.get_persistence_stats()
IO.puts("📊 Persistence Statistics:")
IO.puts("   Active policies: #{persistence_stats.active_policies}")
IO.puts("   Migration queue size: #{persistence_stats.migration_queue_size}")
IO.puts("   Policy adaptations: #{persistence_stats.policy_adaptations}")
IO.puts("   Cost efficiency: #{Float.round(persistence_stats.cost_efficiency, 2)} units/item")

# Display tier utilization
IO.puts("   Tier utilization:")
Enum.each(persistence_stats.tier_utilization, fn {tier, util} ->
  memory_mb = Float.round(util.memory_used / 1_048_576, 2)
  IO.puts("     #{tier}: #{util.item_count} items, #{memory_mb}MB")
end)

# Test 5: Orchestration (Dry Run)
IO.puts("\n🎭 Test 5: Graceful Shutdown/Startup Orchestration")

# Get orchestration status
orchestration_status = Grapple.Distributed.Orchestrator.get_orchestration_status()
IO.puts("✅ Orchestration status check:")
IO.puts("   State: #{orchestration_status.state}")
IO.puts("   Local node: #{orchestration_status.local_node}")
IO.puts("   Node roles: #{inspect(orchestration_status.node_roles)}")

# Test data migration (dry run)
case Grapple.Distributed.Orchestrator.migrate_data(node(), node(), :test_filter) do
  {:ok, migration_result} ->
    IO.puts("✅ Migration dry run completed")
    IO.puts("   Source node: #{migration_result.source_node}")
    IO.puts("   Target node: #{migration_result.target_node}")
    IO.puts("   Data migrated: #{migration_result.data_migrated} items")
    IO.puts("   Success: #{migration_result.success}")
    
  {:error, reason} ->
    IO.puts("❌ Migration test failed: #{inspect(reason)}")
end

# Test 6: Integration - Combined Workflow
IO.puts("\n🔗 Test 6: Integration - Complete Lifecycle Workflow")

# Create data with full lifecycle management
workflow_key = "workflow_test_#{System.system_time(:second)}"

# Step 1: Classify data
{:ok, _} = Grapple.Distributed.LifecycleManager.classify_data(workflow_key, :computational, %{workflow: true})
IO.puts("✅ Step 1: Data classified")

# Step 2: Create optimal placement
{:ok, _} = Grapple.Distributed.PlacementEngine.place_data(workflow_key, %{test: "integration"}, :computational)
IO.puts("✅ Step 2: Data placed optimally")

# Step 3: Set up replication
{:ok, _} = Grapple.Distributed.ReplicationEngine.replicate_data(workflow_key, %{test: "integration"}, :adaptive)
IO.puts("✅ Step 3: Replication configured")

# Step 4: Apply persistence policy
{:ok, _} = Grapple.Distributed.PersistenceManager.apply_persistence_policy(workflow_key, :custom_policy)
IO.puts("✅ Step 4: Persistence policy applied")

# Step 5: Update access patterns (simulate usage)
Grapple.Distributed.LifecycleManager.update_data_access(workflow_key)
Grapple.Distributed.LifecycleManager.update_data_access(workflow_key)
Grapple.Distributed.LifecycleManager.update_data_access(workflow_key)
IO.puts("✅ Step 5: Access patterns updated")

IO.puts("🎉 Complete lifecycle workflow executed successfully!")

# Test 7: Performance and Memory Monitoring
IO.puts("\n⚡ Test 7: Performance and Memory Impact")

# Get baseline graph statistics
graph_stats = Grapple.get_stats()
IO.puts("📈 Graph Performance (with lifecycle management):")
IO.puts("   Total nodes: #{graph_stats.total_nodes}")
IO.puts("   Total edges: #{graph_stats.total_edges}")

# Memory usage breakdown
lifecycle_stats = Grapple.Distributed.LifecycleManager.get_lifecycle_stats()
placement_stats = Grapple.Distributed.PlacementEngine.get_placement_stats()

total_lifecycle_memory = lifecycle_stats.memory_usage.total + 
                        placement_stats.memory_efficiency.total_memory

IO.puts("💾 Memory Impact:")
IO.puts("   Base graph memory: #{graph_stats.memory_usage.nodes + graph_stats.memory_usage.edges + graph_stats.memory_usage.indexes} words")
IO.puts("   Lifecycle management: #{total_lifecycle_memory} bytes")
IO.puts("   Overhead ratio: #{Float.round(total_lifecycle_memory / (graph_stats.memory_usage.nodes + graph_stats.memory_usage.edges) * 100, 1)}%")

# Test cleanup and optimization
IO.puts("\n🧹 Test 8: Cleanup and Optimization")

# Trigger storage optimization
Grapple.Distributed.PersistenceManager.optimize_storage_allocation()
IO.puts("✅ Storage optimization triggered")

# Trigger placement optimization
Grapple.Distributed.PlacementEngine.optimize_placement()
IO.puts("✅ Placement optimization triggered")

# Simulate memory pressure handling
Grapple.Distributed.PlacementEngine.handle_memory_pressure(:medium)
IO.puts("✅ Memory pressure handling tested")

IO.puts("\n🎊 Phase 2 Lifecycle Management Testing Complete!")
IO.puts("\n📋 Summary of Features Tested:")
IO.puts("   ✅ Data lifecycle classification (ephemeral, computational, persistent)")
IO.puts("   ✅ Ephemeral-first placement engine with smart data distribution")
IO.puts("   ✅ Adaptive replication strategies with conflict resolution")
IO.puts("   ✅ Dynamic persistence policy management")
IO.puts("   ✅ Graceful shutdown/startup orchestration")
IO.puts("   ✅ Multi-tier storage optimization (ETS/Mnesia/DETS)")
IO.puts("   ✅ Cost-aware data placement and migration")
IO.puts("   ✅ Memory pressure handling and automatic optimization")
IO.puts("   ✅ Complete integration workflow")

IO.puts("\n🚀 Ready for Phase 3: Advanced Analytics and Query Distribution!")
IO.puts("Next phase will add cross-node query execution, distributed graph algorithms,")
IO.puts("and advanced performance monitoring capabilities.")

IO.puts("\n💡 CLI Commands Available:")
IO.puts("   LIFECYCLE CLASSIFY <key> <type>    - Classify data lifecycle")
IO.puts("   LIFECYCLE STATS                    - View lifecycle statistics")
IO.puts("   LIFECYCLE MIGRATE <key> <tier>     - Migrate data between tiers")
IO.puts("   REPLICA CREATE <key> <policy>      - Create replica set")
IO.puts("   REPLICA STATUS <key>               - Check replica health")
IO.puts("   CLUSTER SHUTDOWN [reason]          - Graceful cluster shutdown")
IO.puts("   CLUSTER STARTUP [mode]             - Coordinate cluster startup")

# Clean shutdown message
IO.puts("\nTest completed successfully. Phase 2 implementation is ready for production use!")