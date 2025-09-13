# Grapple Distributed Mode - Quick Setup Guide

This guide shows how to quickly test the new distributed functionality in Grapple.

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

### In Either Terminal:

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

---

**Ready for distributed graph computing!** 🚀🌐

The minimal implementation provides a solid foundation that can be enhanced incrementally based on specific use case requirements.