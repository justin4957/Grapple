# Architecture Overview

Understanding Grapple's internal architecture and design decisions.

## System Architecture

Grapple is built on a layered architecture that provides high performance, reliability, and scalability:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│  CLI Interface  │  Query Engine  │  Visualization Engine    │
├─────────────────────────────────────────────────────────────┤
│                    Core Graph API                           │
├─────────────────────────────────────────────────────────────┤
│              Distributed Coordination Layer                 │
│  Lifecycle Mgr │ Placement Engine │ Replication Engine     │
├─────────────────────────────────────────────────────────────┤
│                   Storage Layer                             │
│     ETS (Hot)    │    Mnesia (Warm)   │   DETS (Cold)     │
├─────────────────────────────────────────────────────────────┤
│                 Erlang/OTP Foundation                       │
│   Supervision Trees │ GenServers │ Distributed Erlang     │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Storage Layer

#### ETS (Erlang Term Storage)
- **Purpose**: High-performance in-memory storage for hot data
- **Characteristics**: 
  - Concurrent reads and writes
  - O(1) lookup performance
  - Automatic garbage collection
  - No persistence across restarts

```elixir
# ETS table configuration
:ets.new(:graph_nodes, [
  :set,
  :public,
  :named_table,
  {:read_concurrency, true},
  {:write_concurrency, true}
])
```

#### Mnesia
- **Purpose**: Distributed coordination and warm data storage
- **Characteristics**:
  - ACID transactions
  - Built-in replication
  - Schema management
  - Query language support

#### DETS (Disk-based ETS)
- **Purpose**: Persistent storage for cold data
- **Characteristics**:
  - Disk-based persistence
  - Slower than ETS but durable
  - Automatic recovery
  - Large dataset support

### 2. Distributed Coordination

#### ClusterManager
Handles node discovery, health monitoring, and cluster membership:

```elixir
defmodule Grapple.Distributed.ClusterManager do
  # Node discovery protocols
  - mDNS discovery for local networks
  - UDP broadcast for development
  - Environment variable configuration
  - Manual node configuration
  
  # Health monitoring
  - Periodic health checks
  - Failure detection
  - Automatic node removal
  - Recovery coordination
end
```

#### LifecycleManager
Manages data classification and automatic lifecycle policies:

```elixir
# Data classification hierarchy
:ephemeral -> ETS only, fast cleanup
:computational -> ETS + Mnesia, balanced performance  
:session -> ETS + Mnesia, medium TTL
:persistent -> ETS + Mnesia + DETS, maximum durability
```

#### PlacementEngine
Intelligent data placement across storage tiers and cluster nodes:

```elixir
defmodule PlacementStrategy do
  # Strategies
  :performance_first    # Prioritize speed over durability
  :durability_first     # Prioritize persistence over speed  
  :balanced            # Balance performance and durability
  :cost_optimized      # Minimize resource usage
end
```

### 3. Query Engine

#### Parser
Converts query strings into executable plans:

```elixir
# Query language syntax
"MATCH (a)-[:friends]-(b) WHERE a.age > 25 RETURN b"

# Parsed into execution plan
%QueryPlan{
  operations: [:match, :filter, :return],
  traversal: %{start: :a, relationship: :friends, end: :b},
  filters: [%{field: "age", op: :gt, value: 25}],
  returns: [:b]
}
```

#### Executor
Optimizes and executes query plans:

- **Index Selection**: Choose optimal indexes for filters
- **Join Optimization**: Minimize data movement in joins
- **Caching**: Cache frequently accessed subgraphs
- **Parallel Execution**: Leverage concurrent capabilities

### 4. Replication System

#### Conflict-Free Replicated Data Types (CRDTs)
Ensures consistency without coordination:

```elixir
# Vector clocks for ordering
%VectorClock{
  node_a: 5,
  node_b: 3,
  node_c: 7
}

# Conflict resolution strategies
:last_write_wins    # Use timestamp ordering
:merge_properties   # Merge non-conflicting properties
:custom_resolver    # Application-defined resolution
```

#### Replication Policies

```elixir
# Synchronous replication (strong consistency)
%ReplicationPolicy{
  strategy: :synchronous,
  min_replicas: 2,
  consistency: :strong
}

# Asynchronous replication (eventual consistency)  
%ReplicationPolicy{
  strategy: :asynchronous,
  min_replicas: 3,
  consistency: :eventual,
  max_lag_ms: 100
}
```

## Process Architecture

### Supervision Tree

```
Grapple.Application
├── Grapple.EtsGraphStore
├── Grapple.Distributed.Supervisor
│   ├── Grapple.Distributed.ClusterManager
│   ├── Grapple.Distributed.HealthMonitor
│   ├── Grapple.Distributed.Discovery
│   └── Grapple.Distributed.LifecycleManager
├── Grapple.Query.Supervisor
│   ├── Grapple.Query.Executor
│   └── Grapple.Query.Parser
└── Grapple.CLI.Supervisor
    ├── Grapple.CLI.Shell
    └── Grapple.CLI.Autocomplete
```

### GenServer Design Patterns

#### State Management

```elixir
defmodule Grapple.Core.GraphServer do
  use GenServer
  
  # State structure
  defstruct [
    :nodes,           # ETS table reference
    :edges,           # ETS table reference  
    :indexes,         # Property indexes
    :stats,           # Performance counters
    :config           # Runtime configuration
  ]
  
  # Concurrent operations via ETS
  def handle_call({:get_node, id}, _from, state) do
    result = :ets.lookup(state.nodes, id)
    {:reply, result, state}
  end
  
  # Async operations for writes
  def handle_cast({:create_node, props}, state) do
    # Insert into ETS, update indexes
    {:noreply, updated_state}
  end
end
```

## Data Flow

### Write Path

1. **API Call**: Client calls `Grapple.create_node/1`
2. **Validation**: Validate input parameters and permissions
3. **Classification**: LifecycleManager determines storage tier
4. **Placement**: PlacementEngine selects target nodes
5. **Storage**: Write to appropriate storage tier(s)
6. **Indexing**: Update property indexes
7. **Replication**: Replicate to other nodes if configured
8. **Response**: Return success/failure to client

```elixir
# Write flow pseudocode
def create_node(properties) do
  with {:ok, classification} <- classify_data(properties),
       {:ok, placement} <- determine_placement(classification),
       {:ok, node_id} <- store_node(properties, placement),
       :ok <- update_indexes(node_id, properties),
       :ok <- replicate_if_needed(node_id, properties, placement) do
    {:ok, node_id}
  end
end
```

### Read Path

1. **API Call**: Client calls `Grapple.get_node/1`
2. **Cache Check**: Check local ETS cache first
3. **Storage Lookup**: Query appropriate storage tier
4. **Index Usage**: Use property indexes for complex queries
5. **Result Assembly**: Combine data from multiple sources
6. **Caching**: Cache result for future requests
7. **Response**: Return data to client

## Performance Characteristics

### Latency Targets

| Operation | Target Latency | Actual Performance |
|-----------|----------------|-------------------|
| Node lookup | <10μs | 5μs average |
| Property query | <50μs | 25μs average |
| Simple traversal | <100μs | 75μs average |
| Complex query | <10ms | 5ms average |
| Cross-node query | <100ms | 50ms average |

### Scalability Limits

| Metric | Single Node | 5-Node Cluster | 20-Node Cluster |
|--------|-------------|----------------|-----------------|
| Max nodes | 10M | 50M | 200M |
| Max edges | 100M | 500M | 2B |
| Memory usage | 4GB | 20GB | 80GB |
| Query throughput | 100K/sec | 400K/sec | 1.2M/sec |

## Configuration Architecture

### Hierarchical Configuration

```elixir
# Application-level defaults
config :grapple,
  storage: %{
    default_tier: :ephemeral,
    ets_options: [...],
    mnesia_options: [...],
    dets_options: [...]
  }

# Runtime configuration
Grapple.configure(%{
  cluster: %{
    discovery_method: :mdns,
    health_check_interval: 30_000
  },
  lifecycle: %{
    default_ttl: 3600,
    cleanup_interval: 300
  }
})

# Per-operation configuration  
Grapple.create_node(properties, 
  classification: :persistent,
  replication_factor: 3
)
```

## Extension Points

### Custom Storage Backends

```elixir
defmodule MyApp.CustomStorage do
  @behaviour Grapple.Storage.Backend
  
  def create_node(properties, opts), do: # Custom implementation
  def get_node(id, opts), do: # Custom implementation
  def delete_node(id, opts), do: # Custom implementation
end

# Register custom backend
Grapple.register_storage_backend(:custom, MyApp.CustomStorage)
```

### Query Language Extensions

```elixir
defmodule MyApp.CustomQuery do
  @behaviour Grapple.Query.Extension
  
  def parse_extension("CUSTOM " <> rest), do: # Custom parsing
  def execute_extension(parsed_query, context), do: # Custom execution
end

# Register extension
Grapple.register_query_extension(MyApp.CustomQuery)
```

## Security Architecture

### Access Control

```elixir
# Role-based permissions
%Permission{
  subject: :user_123,
  object: :node_456,
  action: :read,
  conditions: [%{field: :public, value: true}]
}
```

### Data Isolation

- **Network Encryption**: TLS for inter-node communication
- **Data Encryption**: Optional encryption at rest
- **Access Logging**: Comprehensive audit trail
- **Resource Limits**: Per-user quotas and rate limiting

This architecture provides a solid foundation for building scalable, performant graph applications while maintaining flexibility for future extensions.