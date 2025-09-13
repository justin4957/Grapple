# Grapple Distributed Mode - Complete Guide

This guide covers both Phase 1 (basic distributed coordination) and Phase 2 (data lifecycle management) features of Grapple's distributed architecture.

## 🚀 Quick Start - Single Machine Multi-Node

### Terminal 1 - First Node
```bash
cd grapple
mix compile
iex --name grapple1@localhost --cookie grapple_cluster -S mix

# Enable distributed mode
Application.put_env(:grapple, :distributed, true)

# Start CLI
Grapple.start_shell()
```

### Terminal 2 - Second Node
```bash
cd grapple  
iex --name grapple2@localhost --cookie grapple_cluster -S mix

# Enable distributed mode
Application.put_env(:grapple, :distributed, true)

# Join the first node
Grapple.Distributed.ClusterManager.join_cluster(:'grapple1@localhost')

# Start CLI
Grapple.start_shell()
```

## 🧪 Test Distributed Features

### Phase 1: Basic Cluster Operations

```bash
# Check cluster status
grapple> CLUSTER STATUS

# Check cluster health
grapple> CLUSTER HEALTH

# Create some data
grapple> CREATE NODE {name: "Alice", city: "SF"}
grapple> CREATE NODE {name: "Bob", city: "NYC"}

# Test data distribution
grapple> SHOW GRAPH
```

### Phase 2: Lifecycle Management (**NEW**)

```bash
# Classify data for different use cases
grapple> LIFECYCLE CLASSIFY user:alice ephemeral
grapple> LIFECYCLE CLASSIFY computation:ml_model computational
grapple> LIFECYCLE CLASSIFY config:system persistent

# View lifecycle statistics
grapple> LIFECYCLE STATS

# Create adaptive replica sets
grapple> REPLICA CREATE critical_data adaptive
grapple> REPLICA STATUS critical_data

# View persistence policies and tier utilization
grapple> LIFECYCLE POLICIES

# Trigger storage optimization
grapple> LIFECYCLE OPTIMIZE

# Migrate data between storage tiers
grapple> LIFECYCLE MIGRATE warm_data mnesia

# Test graceful shutdown (dry run)
grapple> CLUSTER SHUTDOWN planned
grapple> CLUSTER STARTUP standard
```

## 🔍 Verify Multi-Node Coordination

### Check Mnesia Coordination:
```elixir
# See which nodes are connected
Node.list()

# Check Mnesia cluster status
:mnesia.system_info(:running_db_nodes)

# View cluster nodes table
:mnesia.transaction(fn -> :mnesia.all_keys(:cluster_nodes) end)
```

## 🌐 Environment-Based Discovery

For container deployments:

```bash
export GRAPPLE_CLUSTER_NODES="grapple1@localhost,grapple2@localhost"
export GRAPPLE_DISTRIBUTED=true

iex --name grapple3@localhost --cookie grapple_cluster -S mix
```

## 🏥 Test Self-Healing

1. Start 2-3 nodes as above
2. Kill one node (Ctrl+C)
3. Watch the health monitor detect the failure:
   ```bash
   grapple> CLUSTER HEALTH
   ```
4. Restart the node and see it rejoin automatically

## 📊 Features Implemented

### Phase 1: Basic Distributed Coordination

✅ **Basic Cluster Coordination**
- Mnesia-based cluster membership
- Node join/leave operations
- Consistent hashing for data distribution

✅ **Auto-Discovery**  
- Erlang distribution discovery
- UDP broadcast for local networks
- Environment variable configuration

✅ **Health Monitoring**
- Heartbeat-based failure detection
- Automatic cluster state updates
- Recovery coordination

✅ **CLI Integration**
- `CLUSTER STATUS` - Show cluster information
- `CLUSTER HEALTH` - Health monitoring
- `CLUSTER JOIN <node>` - Join clusters

### Phase 2: Data Lifecycle Management (**NEW**)

✅ **Ephemeral-First Data Classification**
- Automatic data lifecycle classification (ephemeral, computational, session, persistent)
- Smart data placement based on usage patterns
- TTL-based automatic cleanup

✅ **Multi-Tier Storage Optimization**
- ETS (fastest, memory-only) for hot data
- Mnesia (fast, replicated) for warm data  
- DETS (persistent, disk-based) for cold data
- Automatic tier migration based on access patterns

✅ **Adaptive Replication Strategies**
- Conflict-free replicated data types (CRDTs)
- Vector clock-based conflict resolution
- Smart replica placement and failover
- Replication policies: minimal, balanced, maximum, adaptive

✅ **Graceful Shutdown/Startup Orchestration**
- Coordinated cluster shutdown with data preservation
- Intelligent startup sequencing
- Emergency failover procedures
- Data migration coordination

✅ **Dynamic Persistence Policies**
- Cost-aware data placement decisions
- Automatic hot/cold data classification
- Memory pressure handling and optimization
- Custom persistence policy creation

✅ **Extended CLI Commands**
- `LIFECYCLE CLASSIFY <key> <type>` - Classify data lifecycle
- `LIFECYCLE STATS` - View lifecycle statistics  
- `LIFECYCLE MIGRATE <key> <tier>` - Migrate data between storage tiers
- `REPLICA CREATE <key> <policy>` - Create replica set with policy
- `REPLICA STATUS <key>` - Check replica health
- `CLUSTER SHUTDOWN [reason]` - Graceful cluster shutdown
- `CLUSTER STARTUP [mode]` - Coordinate cluster startup

## 🔄 Next Phase Features (Unfurling Ready)

The current implementation is minimal but designed for easy expansion:

- **Data Replication**: Automatic multi-node data replication
- **Partition Migration**: Hot rebalancing of data partitions  
- **Consensus Algorithms**: Raft/PBFT for strong consistency
- **Query Distribution**: Cross-node query execution
- **Performance Monitoring**: Distributed metrics collection

## 🐛 Troubleshooting

### Nodes Can't Connect
```bash
# Check Erlang distribution
:net_kernel.monitor_nodes(true)

# Verify cookies match
Node.get_cookie()

# Test connectivity
Node.connect(:'grapple1@localhost')
```

### Mnesia Issues
```bash
# Check Mnesia status
:mnesia.system_info(:is_running)

# Reset if needed (data loss!)
:mnesia.delete_schema([node()])
```

### Discovery Not Working
```bash
# Test UDP broadcast manually
Grapple.Distributed.Discovery.discover_peers()

# Check environment variables
System.get_env("GRAPPLE_CLUSTER_NODES")
```

## 🎯 Production Considerations

For production deployments, consider:

1. **Persistent Mnesia**: Configure disc_copies for cluster state
2. **Network Security**: TLS for inter-node communication  
3. **Service Discovery**: Consul/etcd integration
4. **Monitoring**: Prometheus metrics integration
5. **Backup Strategy**: Mnesia backup and restore procedures

## 🧪 Phase 2 Comprehensive Testing

### Automated Test Suite

Run the comprehensive Phase 2 test suite:

```bash
# Run complete lifecycle management tests
elixir test_phase2_lifecycle.exs
```

This test suite covers:
- Data lifecycle classification system
- Ephemeral-first placement engine
- Smart replication strategies with conflict resolution
- Dynamic persistence policy management
- Graceful shutdown/startup orchestration
- Multi-tier storage optimization
- Complete integration workflows
- Performance and memory impact analysis

### Expected Test Output

The test suite will verify:
- ✅ Data classification for ephemeral, computational, and persistent types
- ✅ Intelligent data placement across ETS/Mnesia/DETS tiers
- ✅ Adaptive replication with configurable policies
- ✅ Cost-aware storage optimization
- ✅ Memory pressure handling and automatic cleanup
- ✅ End-to-end lifecycle workflow integration

## 🔧 Architecture Overview

### Storage Tier Hierarchy

```
┌─────────────────┐
│   ETS (Hot)     │ ← Fastest access, memory-only, ephemeral data
│   - Sub-ms      │
│   - High cost   │
└─────────────────┘
         ↓
┌─────────────────┐
│  Mnesia (Warm)  │ ← Fast access, replicated, computational data
│   - Low ms      │
│   - Med cost    │
└─────────────────┘
         ↓
┌─────────────────┐
│  DETS (Cold)    │ ← Persistent, disk-based, archival data
│   - Higher ms   │
│   - Low cost    │
└─────────────────┘
```

### Lifecycle State Machine

```
[Create] → [Classify] → [Place] → [Replicate] → [Monitor]
                ↓            ↓         ↓          ↓
           [Ephemeral]  → [ETS]   → [Minimal] → [Evict]
           [Computing]  → [Mnesia] → [Balanced] → [Migrate]
           [Persistent] → [DETS]   → [Maximum] → [Archive]
```

### Replication Strategies

- **Minimal**: 1-2 replicas, eventual consistency, cost-optimized
- **Balanced**: 2-3 replicas, strong eventual consistency, performance-balanced  
- **Maximum**: 3-5 replicas, strong consistency, reliability-focused
- **Adaptive**: Auto-scaling based on access patterns and cluster health

---

**Ready for production-grade distributed graph computing!** 🚀🌐

The Phase 2 implementation provides enterprise-ready data lifecycle management with automatic optimization, intelligent replication, and graceful failure handling.