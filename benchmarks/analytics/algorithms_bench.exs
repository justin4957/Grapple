# Benchmark for graph analytics algorithms
#
# Run with: mix run benchmarks/analytics/algorithms_bench.exs
#
# Tests performance of PageRank, centrality, and other graph algorithms

Code.require_file("../support/graph_generator.ex", __DIR__)

IO.puts("Generating graphs for analytics benchmarks...")

# Small graph for quick algorithms
IO.puts("  - Small graph (100 nodes)...")
{small_nodes, _} = Grapple.Benchmarks.GraphGenerator.social_network(100, 8)

# Medium graph for realistic testing
IO.puts("  - Medium graph (1,000 nodes)...")
{medium_nodes, _} = Grapple.Benchmarks.GraphGenerator.social_network(1000, 10)

# Large graph for stress testing
IO.puts("  - Large graph (5,000 nodes)...")
{large_nodes, _} = Grapple.Benchmarks.GraphGenerator.social_network(5000, 8)

IO.puts("\nRunning analytics algorithm benchmarks...\n")
IO.puts("⚠️  Large graph algorithms may take several minutes.\n")

Benchee.run(
  %{
    # === PageRank ===
    "PageRank (100 nodes)" => fn ->
      {:ok, _scores} = Grapple.Analytics.pagerank()
    end,
    "PageRank (1K nodes)" => fn ->
      # Note: This uses the medium graph already created
      {:ok, _scores} = Grapple.Analytics.pagerank()
    end,

    # === Betweenness Centrality ===
    "Betweenness Centrality (100 nodes)" => fn ->
      {:ok, _scores} = Grapple.Analytics.betweenness_centrality()
    end,

    # === Closeness Centrality ===
    "Closeness Centrality (100 nodes)" => fn ->
      {:ok, _scores} = Grapple.Analytics.closeness_centrality()
    end,

    # === Degree Centrality ===
    "Degree Centrality (100 nodes)" => fn ->
      {:ok, _scores} = Grapple.Analytics.degree_centrality()
    end,
    "Degree Centrality (1K nodes)" => fn ->
      {:ok, _scores} = Grapple.Analytics.degree_centrality()
    end,

    # === Connected Components ===
    "Connected Components (100 nodes)" => fn ->
      {:ok, _components} = Grapple.Analytics.connected_components()
    end,
    "Connected Components (1K nodes)" => fn ->
      {:ok, _components} = Grapple.Analytics.connected_components()
    end,

    # === Clustering Coefficient ===
    "Clustering Coefficient (100 nodes)" => fn ->
      {:ok, _coefficients} = Grapple.Analytics.clustering_coefficient()
    end,
    "Clustering Coefficient (1K nodes)" => fn ->
      {:ok, _coefficients} = Grapple.Analytics.clustering_coefficient()
    end,

    # === Graph Summary ===
    "Graph Summary (100 nodes)" => fn ->
      {:ok, _summary} = Grapple.Analytics.summary()
    end,
    "Graph Summary (1K nodes)" => fn ->
      {:ok, _summary} = Grapple.Analytics.summary()
    end,

    # === Connectivity Metrics ===
    "Connectivity Metrics (100 nodes)" => fn ->
      {:ok, _metrics} = Grapple.Analytics.connectivity_metrics()
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/analytics_algorithms.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("\n✅ Analytics algorithms benchmark complete!")
IO.puts("📊 Results saved to: benchmarks/results/analytics_algorithms.html")
IO.puts("\n💡 Key Insight: Algorithm complexity varies - PageRank and Betweenness are O(n²) or worse.")
