# Grapple Architecture Guide

This document provides a comprehensive overview of Grapple's architecture, design decisions, and implementation details for developers who want to understand or contribute to the codebase.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Core Modules](#core-modules)
3. [Storage Layer](#storage-layer)
4. [Query Engine](#query-engine)
5. [Analytics Engine](#analytics-engine)
6. [Distributed Layer](#distributed-layer)
7. [CLI and Interfaces](#cli-and-interfaces)
8. [Data Flow](#data-flow)
9. [Design Decisions](#design-decisions)
10. [Performance Considerations](#performance-considerations)

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Client Layer                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │ Interactive│  │   API      │  │   Query    │  │  Analytics │ │
│  │    CLI     │  │  Client    │  │   DSL      │  │    API     │ │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘ │
└─────────┼────────────────┼────────────────┼────────────────┼──────┘
          │                │                │                │
┌─────────┼────────────────┼────────────────┼────────────────┼──────┐
│         │       Application Layer         │                │      │
│  ┌──────▼─────┐  ┌──────▼─────┐  ┌───────▼──────┐  ┌──────▼────┐│
│  │    CLI     │  │   Public   │  │    Query     │  │ Analytics ││
│  │   Shell    │  │    API     │  │   Executor   │  │  Engine   ││
│  └────────────┘  └────────────┘  └──────────────┘  └───────────┘│
└───────────────────────────────┬──────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────┐
│                       Core Engine Layer                           │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐    │
│  │  Validation &  │  │  Graph Store   │  │  Index Manager  │    │
│  │  Error Handler │  │  (ETS-based)   │  │  (O(1) lookup)  │    │
│  └────────────────┘  └────────────────┘  └─────────────────┘    │
└───────────────────────────────┬──────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────┐
│                      Storage Layer (3-Tier)                       │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────┐    │
│  │   ETS (Hot)    │  │  Mnesia (Warm) │  │   DETS (Cold)   │    │
│  │ • Ephemeral    │─▶│ • Replicated   │─▶│ • Persistent    │    │
│  │ • <1ms         │  │ • 1-5ms        │  │ • Disk-based    │    │
│  └────────────────┘  └────────────────┘  └─────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────┐
│                    Distributed Layer (Optional)                   │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────┐ ┌──────────┐ │
│  │  Cluster    │ │  Replication │ │  Lifecycle  │ │  Health  │ │
│  │  Manager    │ │    Engine    │ │   Manager   │ │ Monitor  │ │
│  └─────────────┘ └──────────────┘ └─────────────┘ └──────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## Core Modules

### 1. Grapple (lib/grapple.ex)
**Purpose**: Main public API and entry point

**Key Functions**:
- `start/0` - Initialize Grapple application
- `start_shell/0` - Launch interactive CLI
- `create_node/1` - Create graph nodes
- `create_edge/4` - Create edges between nodes
- `find_path/2` - Find shortest path between nodes
- `traverse/3` - Traverse graph from starting point

**Dependencies**: All core modules (Storage, Query, Analytics)

### 2. Application (lib/grapple/application.ex)
**Purpose**: OTP application supervisor

**Supervision Tree**:
```
Application
├── EtsGraphStore (GenServer)
├── Performance.Monitor (GenServer, optional)
├── Performance.Profiler (GenServer, optional)
└── Distributed.ClusterManager (GenServer, if enabled)
    ├── Distributed.HealthMonitor
    ├── Distributed.LifecycleManager
    ├── Distributed.ReplicationEngine
    └── Distributed.PersistenceManager
```

## Storage Layer

### EtsGraphStore (lib/grapple/storage/ets_graph_store.ex)
**Purpose**: High-performance in-memory graph storage

**ETS Tables**:
1. `:grapple_nodes` - Node storage (set table)
   - Key: `node_id`
   - Value: `%{id: integer(), properties: map()}`

2. `:grapple_edges` - Edge storage (set table)
   - Key: `edge_id`
   - Value: `%{id: integer(), from: integer(), to: integer(), label: string(), properties: map()}`

3. `:grapple_node_edges_out` - Outgoing edges index (set table)
   - Key: `node_id`
   - Value: `[edge_id, ...]`

4. `:grapple_node_edges_in` - Incoming edges index (set table)
   - Key: `node_id`
   - Value: `[edge_id, ...]`

5. `:grapple_property_index` - Property index (bag table)
   - Key: `{property_key, property_value}`
   - Value: `node_id`

6. `:grapple_label_index` - Label index (bag table)
   - Key: `label`
   - Value: `edge_id`

**Configuration**:
- `read_concurrency: true` - Optimize for concurrent reads
- `write_concurrency: false` - Single writer (GenServer)
- `public` access for direct read operations
- `named_table` for easy access

**Performance**:
- O(1) node/edge lookup by ID
- O(1) property index lookup
- O(k) where k = number of edges for node traversal
- Lock-free concurrent reads

### Three-Tier Storage Strategy

```
┌─────────────────────────────────────────────┐
│ ETS (Hot Tier)                              │
│ • Data Type: Ephemeral, frequently accessed │
│ • Latency: < 1ms                            │
│ • Storage: Memory only                      │
│ • Examples: Active graph nodes, session data│
└─────────────────┬───────────────────────────┘
                  │ TTL expires / access pattern changes
┌─────────────────▼───────────────────────────┐
│ Mnesia (Warm Tier)                          │
│ • Data Type: Computational, replicated      │
│ • Latency: 1-5ms                            │
│ • Storage: Memory + disk backup             │
│ • Examples: Analytics results, cache        │
└─────────────────┬───────────────────────────┘
                  │ Access frequency drops
┌─────────────────▼───────────────────────────┐
│ DETS (Cold Tier)                            │
│ • Data Type: Persistent, archival           │
│ • Latency: 10-50ms (disk I/O)               │
│ • Storage: Disk only                        │
│ • Examples: Historical data, backups        │
└─────────────────────────────────────────────┘
```

## Query Engine

### Query Language (lib/grapple/query/language.ex)
**Purpose**: Parse Cypher-like query syntax

**Supported Patterns**:
```cypher
MATCH (n)-[r]->(m)              # Basic pattern matching
MATCH (n:Person)-[r:KNOWS]->(m) # With labels (future)
WHERE n.age > 25                # Filtering
RETURN n, r, m                  # Result projection
```

**Parser Pipeline**:
1. Tokenize query string
2. Parse pattern (nodes, edges, relationships)
3. Extract WHERE conditions
4. Build query plan
5. Execute via Executor

### Query Executor (lib/grapple/query/executor.ex)
**Purpose**: Execute parsed queries efficiently

**Execution Strategy**:
1. **Index Selection**: Choose optimal starting point
   - Check if property index available
   - Fall back to full scan if needed

2. **Pattern Matching**: BFS/DFS traversal
   - Expand from starting nodes
   - Filter by edge labels and properties
   - Match destination nodes

3. **Filtering**: Apply WHERE clauses
   - Property comparisons
   - Range queries
   - Boolean logic

4. **Projection**: Return results
   - Extract requested fields
   - Format as result set

**Optimization**:
- Query plan caching
- Index usage recommendations
- Early termination when possible

### ETS Optimizer (lib/grapple/query/ets_optimizer.ex)
**Purpose**: Query plan optimization and caching

**Features**:
- Query plan cache (memoization)
- Index usage analysis
- Cost-based query planning
- Statistics collection

## Analytics Engine

### Analytics Module Structure

```
lib/grapple/analytics/
├── analytics.ex              # Public API
├── centrality.ex            # Centrality algorithms
├── community.ex             # Community detection
└── metrics.ex               # Graph metrics
```

### Centrality (lib/grapple/analytics/centrality.ex)
**Algorithms Implemented**:

1. **PageRank** (Power Iteration Method)
   - Time Complexity: O(iterations × edges)
   - Space Complexity: O(nodes)
   - Typical Convergence: 20-50 iterations
   - Implementation: Iterative rank propagation with normalization

2. **Betweenness Centrality** (Brandes' Algorithm)
   - Time Complexity: O(nodes × edges)
   - Space Complexity: O(nodes + edges)
   - Implementation: BFS from each node, dependency accumulation

3. **Closeness Centrality** (BFS-based)
   - Time Complexity: O(nodes + edges) per node
   - Implementation: Shortest path sum calculation

### Community (lib/grapple/analytics/community.ex)
**Algorithms Implemented**:

1. **Connected Components** (Union-Find)
   - Time Complexity: O(nodes + edges) with path compression
   - Space Complexity: O(nodes)
   - Implementation: Disjoint-set data structure with union by rank

2. **Clustering Coefficient** (Triangle Counting)
   - Global: Ratio of closed triplets
   - Local: Per-node clustering
   - Time Complexity: O(nodes × degree²)

### Metrics (lib/grapple/analytics/metrics.ex)
**Metrics Implemented**:

- Graph Density: edges / possible_edges
- Diameter: Longest shortest path
- Degree Distribution: Statistical analysis
- Average Path Length: Mean shortest paths
- Connectivity: Component analysis

## Distributed Layer

### Cluster Manager (lib/grapple/distributed/cluster_manager.ex)
**Purpose**: Multi-node cluster coordination

**Features**:
- Automatic node discovery
- Cluster state synchronization
- Partition management
- Node health monitoring

**Communication**:
- Erlang distribution protocol
- Node.connect/1 for cluster joining
- :rpc for remote procedure calls

### Replication Engine (lib/grapple/distributed/replication_engine.ex)
**Purpose**: Data replication across nodes

**Replication Strategies**:
1. **Minimal**: 1 primary + 1 replica
2. **Balanced**: 1 primary + 2 replicas
3. **Maximum**: 1 primary + all available nodes
4. **Adaptive**: Dynamic based on load and importance

**Conflict Resolution**:
- CRDT-based eventual consistency
- Last-write-wins with timestamps
- Custom merge strategies

### Lifecycle Manager (lib/grapple/distributed/lifecycle_manager.ex)
**Purpose**: Data classification and tier management

**Data Classifications**:
- Ephemeral: Short-lived, hot tier
- Computational: Medium-lived, warm tier
- Session: User-specific, warm tier
- Persistent: Long-lived, cold tier

**Migration Policies**:
- Access frequency tracking
- Automatic tier promotion/demotion
- Cost optimization

## CLI and Interfaces

### CLI Shell (lib/grapple/cli/shell.ex)
**Purpose**: Interactive command-line interface

**Features**:
- TAB completion (via Autocomplete module)
- Command history
- Error formatting with suggestions
- ASCII visualization
- Real-time analytics commands

**Command Categories**:
1. Graph Operations (CREATE, MATCH, FIND, etc.)
2. Analytics (ANALYTICS PAGERANK, etc.)
3. Distributed Operations (CLUSTER, LIFECYCLE, REPLICA)
4. System (help, quit)

### Autocomplete (lib/grapple/cli/autocomplete.ex)
**Purpose**: TAB completion and command suggestions

**Features**:
- Command name completion
- Parameter suggestions
- Smart filtering based on context
- Multi-level completion support

## Data Flow

### Node Creation Flow
```
Client Request
    │
    ▼
Grapple.create_node(%{properties})
    │
    ▼
Validation.validate_node_properties(properties)
    │
    ▼
EtsGraphStore.create_node(validated_properties)
    │
    ├─▶ Generate node_id
    ├─▶ Insert into :grapple_nodes
    ├─▶ Initialize adjacency lists
    └─▶ Update property indexes
    │
    ▼
Return {:ok, node_id}
```

### Query Execution Flow
```
Query String: "MATCH (n)-[r]->(m) WHERE n.age > 25"
    │
    ▼
Language.parse(query)
    │
    ├─▶ Tokenize
    ├─▶ Parse pattern
    ├─▶ Extract conditions
    └─▶ Build query plan
    │
    ▼
Executor.execute(query_plan)
    │
    ├─▶ Select starting nodes (via index or scan)
    ├─▶ Traverse edges matching pattern
    ├─▶ Filter by WHERE conditions
    └─▶ Project results
    │
    ▼
Return {:ok, results}
```

### Analytics Flow
```
Grapple.Analytics.pagerank()
    │
    ▼
EtsGraphStore.list_nodes() + list_edges()
    │
    ▼
Build adjacency structure
    │
    ▼
Initialize PageRank values
    │
    ▼
Iterate until convergence
    │
    ├─▶ Calculate new ranks
    ├─▶ Check convergence
    └─▶ Normalize results
    │
    ▼
Return {:ok, %{node_id => rank, ...}}
```

## Design Decisions

### Why ETS for Primary Storage?

**Pros**:
- Sub-millisecond latency
- Lock-free concurrent reads
- No serialization overhead
- Built into BEAM VM

**Cons**:
- Memory-only (addressed by tiered storage)
- Single-node (addressed by replication)
- No durability (addressed by DETS backup)

**Alternative Considered**: Mnesia
- Rejected for primary storage due to write lock overhead
- Used instead for warm tier (balanced read/write needs)

### Why GenServer for Writes?

**Reasoning**:
- Guarantees write serialization
- Prevents race conditions
- Simplifies consistency model
- ETS tables are public for reads

**Trade-off**:
- Write throughput limited by single process
- Acceptable for graph workloads (reads >> writes)
- Can be scaled horizontally via sharding

### Why Cypher-like Syntax?

**Reasoning**:
- Industry standard (Neo4j, Memgraph)
- Intuitive pattern matching
- Declarative query style
- Easy to learn

**Alternative Considered**: Gremlin
- More verbose
- Imperative style less intuitive
- Less adoption in Elixir ecosystem

### Why Union-Find for Connected Components?

**Reasoning**:
- Near-linear time complexity with path compression
- Simple implementation
- Optimal for static graphs
- Excellent performance

**Alternative Considered**: DFS/BFS
- Same time complexity
- More complex state management
- Union-Find cleaner for this use case

## Performance Considerations

### Bottlenecks and Mitigations

1. **Write Throughput**
   - Bottleneck: Single GenServer writer
   - Mitigation: Batch writes, async operations
   - Future: Shard by node ID range

2. **Memory Usage**
   - Bottleneck: All data in memory (ETS)
   - Mitigation: Tiered storage, data classification
   - Future: LRU eviction, memory limits

3. **Analytics Performance**
   - Bottleneck: O(n²) or O(n×m) algorithms
   - Mitigation: Caching, incremental updates
   - Future: Parallel execution, sampling

4. **Network Overhead (Distributed)**
   - Bottleneck: Inter-node RPC calls
   - Mitigation: Batch operations, local caching
   - Future: Gossip protocol, lazy replication

### Optimization Techniques

1. **Index Usage**
   - Property indexes for O(1) lookup
   - Label indexes for edge filtering
   - Adjacency lists for O(k) traversal

2. **Caching**
   - Query plan cache
   - Analytics result cache
   - Frequently accessed path cache

3. **Lazy Evaluation**
   - Stream-based result sets
   - Pagination support
   - Early termination

4. **Concurrent Execution**
   - Parallel analytics (future)
   - Concurrent query execution
   - Read parallelism via ETS

## Module Dependency Graph

```
                      Grapple (Public API)
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    CLI.Shell        Query.Executor    Analytics
         │                 │                 │
         │                 │                 │
    Autocomplete     Query.Language    Centrality
                          │            Community
                          │            Metrics
                          │                 │
                          └─────────┬───────┘
                                    │
                              EtsGraphStore
                                    │
                              ┌─────┴─────┐
                         Validation    Error
```

## Testing Strategy

### Test Coverage by Layer

1. **Unit Tests** (~40% of tests)
   - Individual module functions
   - Edge cases and error conditions
   - Validation logic

2. **Integration Tests** (~40% of tests)
   - Multi-module interactions
   - Query execution end-to-end
   - Analytics pipelines

3. **Property-Based Tests** (~10% of tests)
   - Graph properties (invariants)
   - Query result consistency
   - Analytics correctness

4. **Doctests** (~10% of tests)
   - API documentation examples
   - Quick sanity checks

### Critical Test Areas

1. **Correctness**
   - Graph integrity (no orphaned edges)
   - Query result accuracy
   - Analytics algorithm correctness

2. **Performance**
   - Benchmark regressions
   - Memory leak detection
   - Concurrency stress tests

3. **Error Handling**
   - Invalid input handling
   - Resource exhaustion
   - Network failures (distributed mode)

## Future Architecture Changes

### Planned Improvements

1. **Horizontal Scaling**
   - Shard graph by node ID ranges
   - Distributed query execution
   - Cross-shard joins

2. **Advanced Indexing**
   - Composite indexes
   - Full-text search integration
   - Spatial indexes

3. **Query Optimization**
   - Cost-based optimizer
   - Join order optimization
   - Materialized views

4. **Streaming**
   - Streaming query results
   - Real-time graph updates
   - Event-driven architecture

5. **Visualization**
   - Phoenix LiveView dashboard
   - D3.js/Cytoscape.js integration
   - Real-time graph visualization

---

This architecture is designed to be:
- **Performant**: Leverage BEAM VM strengths
- **Scalable**: Horizontal scaling via distribution
- **Maintainable**: Clear module boundaries
- **Extensible**: Plugin architecture for algorithms
- **Developer-Friendly**: Clear APIs and excellent documentation

For more details on specific modules, see the inline documentation and test files.
