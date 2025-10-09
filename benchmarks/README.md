# Grapple Benchmarks

Comprehensive performance benchmarking suite for Grapple Graph Database.

## Quick Start

```bash
# Run all core benchmarks
mix bench

# Run specific benchmark
mix run benchmarks/core/node_operations_bench.exs

# Run with HTML output
mix bench --html
```

## Benchmark Suites

### Core Operations (`benchmarks/core/`)

Fundamental operations that form the basis of graph database interactions:

- **`node_operations_bench.exs`** - Node CRUD, property queries
  - Single/batch node creation
  - Node retrieval
  - Property-based lookups

- **`edge_operations_bench.exs`** - Edge CRUD, label queries
  - Single/batch edge creation
  - Edge retrieval
  - Label-based lookups

- **`traversal_bench.exs`** - Graph traversal and path finding
  - BFS traversal at various depths
  - Shortest path finding
  - Different graph structures

### Scalability (`benchmarks/scalability/`) - Coming Soon

- Graph size scaling (100 to 1M+ nodes)
- Concurrent load testing
- Memory profiling

### Analytics (`benchmarks/analytics/`) - Coming Soon

- PageRank
- Centrality algorithms
- Community detection

## Running Benchmarks

### Run All Core Benchmarks

```bash
mix bench
```

### Run Individual Benchmarks

```bash
# Node operations
mix run benchmarks/core/node_operations_bench.exs

# Edge operations
mix run benchmarks/core/edge_operations_bench.exs

# Traversal
mix run benchmarks/core/traversal_bench.exs
```

### Generate HTML Reports

Benchmarks automatically generate HTML reports in `benchmarks/results/`:

- `node_operations.html`
- `edge_operations.html`
- `traversal.html`

Open these files in your browser for interactive charts and detailed statistics.

## Understanding Results

### Console Output

```
Name                                 ips        average  deviation         median         99th %
create_node (minimal)             312.5K        3.2 μs    ±15.2%        3.1 μs        4.8 μs
create_node (3 properties)        285.3K        3.5 μs    ±12.1%        3.4 μs        5.2 μs
find_nodes_by_property (1K)       523.7K        1.9 μs     ±8.3%        1.8 μs        2.8 μs
```

**Key Metrics:**
- **ips**: Iterations per second (operations/sec)
- **average**: Mean execution time
- **median**: 50th percentile latency
- **99th %**: 99th percentile latency (worst-case performance)

### Memory Usage

```
Memory usage statistics:
  create_node (minimal):       456 B
  create_node (3 properties):  512 B
  find_nodes_by_property:      2.4 KB
```

## Benchmark Configuration

All benchmarks use these default settings:

```elixir
time: 5           # Run each scenario for 5 seconds
memory_time: 2    # Measure memory for 2 seconds
```

You can modify these in individual benchmark files for faster or more thorough testing.

## Writing New Benchmarks

### Example Structure

```elixir
# benchmarks/my_custom_bench.exs

# Setup
IO.puts("Setting up test data...")
{:ok, node_id} = Grapple.create_node(%{type: "test"})

# Run benchmarks
Benchee.run(
  %{
    "my_operation" => fn ->
      # Your operation here
      Grapple.some_operation(node_id)
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/my_custom.html"}
  ]
)
```

### Using Graph Generator

The `Grapple.Benchmarks.GraphGenerator` module provides utilities for creating test graphs:

```elixir
Code.require_file("support/graph_generator.ex", "benchmarks")

# Random graph
{nodes, edges} = Grapple.Benchmarks.GraphGenerator.random_graph(1000, 5000)

# Linear chain
{nodes, edges} = Grapple.Benchmarks.GraphGenerator.linear_chain(100)

# Binary tree
{nodes, edges} = Grapple.Benchmarks.GraphGenerator.binary_tree(6)

# Dense graph
{nodes, edges} = Grapple.Benchmarks.GraphGenerator.dense_graph(500, 0.7)

# Social network (power-law distribution)
{nodes, edges} = Grapple.Benchmarks.GraphGenerator.social_network(1000, 10)
```

## Performance Targets

Based on Grapple's design goals:

| Operation | Target | Actual |
|-----------|--------|--------|
| Node creation | 300K+ ops/sec | Run benchmarks to verify |
| Edge creation | 250K+ ops/sec | Run benchmarks to verify |
| Property lookup | 500K+ ops/sec | Run benchmarks to verify |
| Traversal (depth 3) | 100K+ ops/sec | Run benchmarks to verify |
| Path finding | <2ms for typical graphs | Run benchmarks to verify |

Run the benchmarks to validate these targets on your hardware!

## CI Integration

### GitHub Actions (Coming Soon)

Benchmarks will be integrated into CI to:
- Run on every PR
- Detect performance regressions
- Compare against main branch
- Generate trend reports

### Regression Detection

Fails if performance degrades by >10%:

```bash
mix bench.compare main  # Compare current branch against main
```

## Interpreting Benchmark Results

### What "Good" Looks Like

✅ **Good Performance:**
- Node creation: >200K ops/sec
- Property lookups: >400K ops/sec
- Low variance (<15% deviation)
- Sub-millisecond p99 latency

⚠️ **Needs Investigation:**
- <100K ops/sec for basic operations
- High variance (>25% deviation)
- Multi-millisecond latencies
- Increasing memory usage

### Common Issues

**Slow node creation:**
- Check if ETS tables are properly configured
- Verify indexing overhead isn't excessive

**Slow property lookups:**
- Should be O(1) - investigate if not sub-millisecond
- Check index implementation

**High memory usage:**
- Monitor GC frequency
- Check for memory leaks in long-running benchmarks

## Hardware Considerations

Benchmark results vary by hardware. Typical ranges:

**Modern Desktop (Ryzen/Intel i7):**
- Node creation: 250-400K ops/sec
- Property lookups: 400-700K ops/sec

**Laptop (MacBook Pro M1/M2):**
- Node creation: 300-500K ops/sec
- Property lookups: 500-900K ops/sec

**Server (Multi-core Xeon):**
- Node creation: 400-600K ops/sec (with concurrency)
- Property lookups: 600K-1M ops/sec

## Troubleshooting

### Benchmarks fail to run

```bash
# Ensure dependencies are installed
mix deps.get

# Compile the project
mix compile

# Try running with verbose output
elixir -r benchmarks/support/graph_generator.ex benchmarks/core/node_operations_bench.exs
```

### Memory errors with large graphs

Reduce graph sizes in scalability benchmarks or increase VM memory:

```bash
elixir --erl "+MBas aobf +MBlmbcs 512 +MBsbcs 512" -S mix bench
```

### Results directory missing

```bash
mkdir -p benchmarks/results
```

## Contributing

When adding new benchmarks:

1. ✅ Place in appropriate directory (`core/`, `scalability/`, `analytics/`)
2. ✅ Use descriptive scenario names
3. ✅ Include both single and batch operations
4. ✅ Add memory profiling
5. ✅ Generate HTML output
6. ✅ Document in this README
7. ✅ Update performance targets if needed

## Resources

- [Benchee Documentation](https://hexdocs.pm/benchee/)
- [Grapple Performance Guide](../guides/advanced/performance.md)
- [Issue #29 - Comprehensive Benchmarking](https://github.com/justin4957/Grapple/issues/29)

---

**Questions?** Open an issue or check the [performance guide](../guides/advanced/performance.md).
