# Performance Guide

Optimize your Grapple graph database for maximum performance across different workloads.

## Performance Overview

Grapple achieves high performance through:

- **ETS Storage**: In-memory tables optimized for concurrent access
- **Efficient Indexing**: Automatic property indexing for fast lookups
- **Query Optimization**: Smart traversal algorithms and caching
- **Distributed Architecture**: Horizontal scaling with intelligent placement

## Benchmarks

### Single Node Performance

| Operation | Throughput | Latency |
|-----------|------------|---------|
| Node Creation | 300K+ ops/sec | <10μs |
| Edge Creation | 250K+ ops/sec | <15μs |
| Neighbor Lookup | 500K+ ops/sec | <5μs |
| Property Query | 400K+ ops/sec | <8μs |
| Path Finding | 50K+ ops/sec | <100μs |

### Memory Usage

| Graph Size | Memory Usage | Lookup Time |
|------------|--------------|-------------|
| 1K nodes | ~2MB | <1μs |
| 10K nodes | ~15MB | <2μs |
| 100K nodes | ~120MB | <5μs |
| 1M nodes | ~1.2GB | <10μs |

## Optimization Strategies

### 1. Storage Tier Selection

Choose the right storage tier for your data:

```elixir
# Hot data - frequent access
Grapple.LifecycleManager.classify_data(key, :ephemeral, %{
  ttl: 3600,
  access_pattern: :frequent
})

# Warm data - moderate access
Grapple.LifecycleManager.classify_data(key, :computational, %{
  ttl: 86400,
  access_pattern: :moderate
})

# Cold data - archival
Grapple.LifecycleManager.classify_data(key, :persistent, %{
  replication_factor: 3,
  persistence_policy: :durable
})
```

### 2. Query Optimization

#### Efficient Traversals

```elixir
# Good: Limit traversal depth
neighbors = Grapple.traverse(node_id, depth: 2, limit: 100)

# Good: Filter by edge type
friends = Grapple.get_neighbors(node_id, edge_type: "friends")

# Avoid: Unlimited traversals
# bad_result = Grapple.traverse(node_id) # Can traverse entire graph
```

#### Property Indexing

```elixir
# Properties are auto-indexed, but you can optimize:
Grapple.create_node(%{
  # Indexed properties (frequently queried)
  user_id: "user123",
  email: "user@example.com",
  
  # Non-indexed bulk data
  profile_data: large_blob
})
```

#### Batch Operations

```elixir
# Good: Batch node creation
nodes = 1..1000
|> Enum.map(fn i -> %{id: i, name: "Node #{i}"} end)
|> Enum.map(&Grapple.create_node/1)

# Good: Transaction for related operations
Grapple.transaction(fn ->
  {:ok, node1} = Grapple.create_node(%{name: "Alice"})
  {:ok, node2} = Grapple.create_node(%{name: "Bob"})
  {:ok, _edge} = Grapple.create_edge(node1, node2, "friends")
end)
```

### 3. Memory Management

#### Monitor ETS Usage

```elixir
# Check memory usage
stats = Grapple.stats()
%{
  nodes: node_count,
  edges: edge_count,
  memory_mb: memory_usage,
  ets_tables: table_info
} = stats

# Set memory limits
Grapple.configure(max_memory_mb: 1024)
```

#### Garbage Collection Tuning

```elixir
# In your application config
config :grapple,
  gc_settings: %{
    ttl_cleanup_interval: 60_000,  # 1 minute
    memory_pressure_threshold: 0.8,
    aggressive_gc_threshold: 0.9
  }
```

### 4. Distributed Performance

#### Node Placement Strategy

```elixir
# Configure placement for optimal performance
Grapple.PlacementEngine.configure(%{
  strategy: :performance_optimized,
  locality_preference: true,
  load_balancing: :round_robin,
  hot_data_replication: 3
})
```

#### Network Optimization

```elixir
# Minimize network hops
config :grapple, :distributed,
  network_compression: true,
  batch_replication: true,
  async_writes: true,
  read_preference: :local_first
```

## Performance Monitoring

### Built-in Metrics

```elixir
# Get detailed performance stats
perf_stats = Grapple.performance_stats()
%{
  throughput: %{
    reads_per_sec: 50000,
    writes_per_sec: 30000
  },
  latency: %{
    p50_read_us: 5,
    p95_read_us: 15,
    p99_read_us: 50
  },
  memory: %{
    total_mb: 245,
    ets_mb: 200,
    process_mb: 45
  },
  cluster: %{
    nodes: 3,
    replication_lag_ms: 2,
    network_usage_mbps: 12
  }
}
```

### Custom Monitoring

```elixir
defmodule MyApp.GraphMonitor do
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    :timer.send_interval(5000, :collect_metrics)
    {:ok, %{}}
  end
  
  def handle_info(:collect_metrics, state) do
    stats = Grapple.stats()
    
    # Log performance metrics
    Logger.info("Graph stats: #{inspect(stats)}")
    
    # Check for performance issues
    if stats.memory_mb > 1000 do
      Logger.warn("High memory usage: #{stats.memory_mb}MB")
    end
    
    {:noreply, state}
  end
end
```

## Performance Testing

### Load Testing

```elixir
defmodule Grapple.LoadTest do
  def run_write_test(num_operations \\ 10_000) do
    start_time = System.monotonic_time(:microsecond)
    
    tasks = 1..num_operations
    |> Task.async_stream(fn i ->
      {:ok, _} = Grapple.create_node(%{id: i, data: "test_#{i}"})
    end, max_concurrency: 100)
    |> Enum.to_list()
    
    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000
    
    ops_per_sec = num_operations / (duration_ms / 1000)
    
    IO.puts("Write test: #{num_operations} operations in #{duration_ms}ms")
    IO.puts("Throughput: #{round(ops_per_sec)} ops/sec")
  end
  
  def run_read_test(num_operations \\ 10_000) do
    # Create test data first
    node_ids = 1..1000
    |> Enum.map(fn i ->
      {:ok, id} = Grapple.create_node(%{id: i})
      id
    end)
    
    start_time = System.monotonic_time(:microsecond)
    
    tasks = 1..num_operations
    |> Task.async_stream(fn _ ->
      node_id = Enum.random(node_ids)
      Grapple.get_node(node_id)
    end, max_concurrency: 100)
    |> Enum.to_list()
    
    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000
    
    ops_per_sec = num_operations / (duration_ms / 1000)
    
    IO.puts("Read test: #{num_operations} operations in #{duration_ms}ms")
    IO.puts("Throughput: #{round(ops_per_sec)} ops/sec")
  end
end

# Run tests
Grapple.LoadTest.run_write_test()
Grapple.LoadTest.run_read_test()
```

## Troubleshooting Performance Issues

### Common Issues

1. **Slow Queries**
   - Check traversal depth limits
   - Verify property indexing
   - Monitor memory pressure

2. **High Memory Usage**
   - Review TTL policies
   - Check for memory leaks
   - Optimize data structures

3. **Network Bottlenecks**
   - Monitor replication lag
   - Check network bandwidth
   - Optimize data placement

### Debugging Tools

```elixir
# Profile query performance
{time, result} = :timer.tc(fn ->
  Grapple.complex_query(params)
end)

# Memory profiling
:recon.memory_usage(:usage)

# Process monitoring
:recon.proc_count(:memory, 10)
```

## Production Configuration

```elixir
# config/prod.exs
config :grapple,
  # Performance settings
  ets_options: [
    :set,
    :public,
    :named_table,
    {:read_concurrency, true},
    {:write_concurrency, true}
  ],
  
  # Memory management
  max_memory_mb: 4096,
  gc_interval_ms: 30_000,
  
  # Distributed settings
  cluster_size: 5,
  replication_factor: 3,
  consistency_level: :eventual,
  
  # Monitoring
  metrics_enabled: true,
  telemetry_enabled: true
```

This guide provides comprehensive strategies for optimizing Grapple performance across different scenarios and workloads.