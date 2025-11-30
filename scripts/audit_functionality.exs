# Grapple Functionality Audit Script
# Tests all major features and documents any issues

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("GRAPPLE FUNCTIONALITY AUDIT")
IO.puts(String.duplicate("=", 80) <> "\n")

defmodule GrappleAudit do
  @moduledoc """
  Comprehensive audit of all Grapple functionality.
  """

  def run do
    results = %{
      core: audit_core_operations(),
      analytics: audit_analytics(),
      auth: audit_authentication(),
      search: audit_search(),
      query: audit_query_language(),
      distributed: audit_distributed(),
      performance: audit_performance()
    }

    print_summary(results)
    results
  end

  ## Core Graph Operations
  def audit_core_operations do
    IO.puts("📊 AUDITING CORE GRAPH OPERATIONS\n")
    issues = []

    # Test 1: Node creation
    IO.puts("  ✓ Testing node creation...")
    {:ok, node1} = Grapple.create_node(%{name: "Alice", role: "Engineer", age: 30})
    {:ok, node2} = Grapple.create_node(%{name: "Bob", role: "Manager", age: 35})
    {:ok, node3} = Grapple.create_node(%{name: "Charlie", role: "Engineer", age: 28})
    IO.puts("    Created 3 nodes: #{node1}, #{node2}, #{node3}")

    # Test 2: Node retrieval
    IO.puts("  ✓ Testing node retrieval...")
    {:ok, retrieved} = Grapple.get_node(node1)
    if retrieved.properties.name != "Alice" do
      issues = issues ++ ["Node retrieval returned incorrect data"]
    end

    # Test 3: Edge creation
    IO.puts("  ✓ Testing edge creation...")
    {:ok, edge1} = Grapple.create_edge(node1, node2, "reports_to", %{since: "2023"})
    {:ok, edge2} = Grapple.create_edge(node3, node2, "reports_to", %{since: "2024"})
    {:ok, edge3} = Grapple.create_edge(node1, node3, "mentors", %{topic: "coding"})
    IO.puts("    Created 3 edges: #{edge1}, #{edge2}, #{edge3}")

    # Test 4: Property-based search
    IO.puts("  ✓ Testing property-based node search...")
    {:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
    if length(engineers) != 2 do
      issues = issues ++ ["Property search returned wrong count: expected 2, got #{length(engineers)}"]
    end

    # Test 5: Label-based edge search
    IO.puts("  ✓ Testing label-based edge search...")
    {:ok, reports} = Grapple.find_edges_by_label("reports_to")
    if length(reports) != 2 do
      issues = issues ++ ["Edge label search returned wrong count: expected 2, got #{length(reports)}"]
    end

    # Test 6: Graph statistics
    IO.puts("  ✓ Testing graph statistics...")
    stats = Grapple.get_stats()
    IO.puts("    Total nodes: #{stats.total_nodes}")
    IO.puts("    Total edges: #{stats.total_edges}")
    IO.puts("    Memory usage: #{inspect(stats.memory_usage)}")

    # Test 7: Path finding
    IO.puts("  ✓ Testing path finding...")
    case Grapple.find_path(node1, node2) do
      {:ok, path} ->
        IO.puts("    Found path: #{inspect(path)}")
      {:error, reason} ->
        issues = issues ++ ["Path finding failed: #{reason}"]
    end

    # Test 8: Graph traversal
    IO.puts("  ✓ Testing graph traversal...")
    case Grapple.traverse(node2, :in, 1) do
      {:ok, neighbors} ->
        IO.puts("    Found #{length(neighbors)} neighbors")
      {:error, reason} ->
        issues = issues ++ ["Traversal failed: #{reason}"]
    end

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Analytics
  def audit_analytics do
    IO.puts("📈 AUDITING ANALYTICS & ALGORITHMS\n")
    issues = []

    # Create a test graph
    {:ok, n1} = Grapple.create_node(%{name: "Node1"})
    {:ok, n2} = Grapple.create_node(%{name: "Node2"})
    {:ok, n3} = Grapple.create_node(%{name: "Node3"})
    {:ok, n4} = Grapple.create_node(%{name: "Node4"})

    Grapple.create_edge(n1, n2, "connects")
    Grapple.create_edge(n2, n3, "connects")
    Grapple.create_edge(n3, n1, "connects")
    Grapple.create_edge(n1, n4, "connects")

    # Test PageRank
    IO.puts("  ✓ Testing PageRank...")
    case Grapple.Analytics.pagerank() do
      {:ok, ranks} ->
        IO.puts("    PageRank computed: #{map_size(ranks)} nodes ranked")
      {:error, reason} ->
        issues = issues ++ ["PageRank failed: #{reason}"]
    end

    # Test Betweenness Centrality
    IO.puts("  ✓ Testing Betweenness Centrality...")
    case Grapple.Analytics.betweenness_centrality() do
      {:ok, centrality} ->
        IO.puts("    Centrality computed for #{map_size(centrality)} nodes")
      {:error, reason} ->
        issues = issues ++ ["Betweenness centrality failed: #{reason}"]
    end

    # Test Connected Components
    IO.puts("  ✓ Testing Connected Components...")
    case Grapple.Analytics.connected_components() do
      {:ok, components} ->
        IO.puts("    Found #{length(components)} connected components")
      {:error, reason} ->
        issues = issues ++ ["Connected components failed: #{reason}"]
    end

    # Test Clustering Coefficient
    IO.puts("  ✓ Testing Clustering Coefficient...")
    case Grapple.Analytics.clustering_coefficient() do
      {:ok, coefficient} ->
        IO.puts("    Clustering coefficient: #{coefficient}")
      {:error, reason} ->
        issues = issues ++ ["Clustering coefficient failed: #{reason}"]
    end

    # Test Graph Density
    IO.puts("  ✓ Testing Graph Density...")
    case Grapple.Analytics.graph_density() do
      {:ok, density} ->
        IO.puts("    Graph density: #{density}")
      {:error, reason} ->
        issues = issues ++ ["Graph density failed: #{reason}"]
    end

    # Test Degree Distribution
    IO.puts("  ✓ Testing Degree Distribution...")
    case Grapple.Analytics.degree_distribution() do
      {:ok, dist} ->
        IO.puts("    Degree distribution: min=#{dist.min}, max=#{dist.max}, mean=#{Float.round(dist.mean, 2)}")
      {:error, reason} ->
        issues = issues ++ ["Degree distribution failed: #{reason}"]
    end

    # Test Community Detection
    IO.puts("  ✓ Testing Community Detection (Louvain)...")
    case Grapple.Analytics.Community.louvain_communities() do
      {:ok, communities} ->
        IO.puts("    Found #{map_size(communities)} community assignments")
      {:error, reason} ->
        issues = issues ++ ["Louvain community detection failed: #{reason}"]
    end

    # Test Centrality algorithms
    IO.puts("  ✓ Testing Eigenvector Centrality...")
    case Grapple.Analytics.Centrality.eigenvector_centrality() do
      {:ok, centrality} ->
        IO.puts("    Eigenvector centrality computed for #{map_size(centrality)} nodes")
      {:error, reason} ->
        issues = issues ++ ["Eigenvector centrality failed: #{reason}"]
    end

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Authentication & Authorization
  def audit_authentication do
    IO.puts("🔐 AUDITING AUTHENTICATION & AUTHORIZATION\n")
    issues = []

    # Test user registration
    IO.puts("  ✓ Testing user registration...")
    case Grapple.Auth.register("audit_user", "test_password", [:read_write]) do
      {:ok, user} ->
        IO.puts("    Created user: #{user.username}")

        # Test login
        IO.puts("  ✓ Testing login...")
        case Grapple.Auth.login("audit_user", "test_password") do
          {:ok, token, _claims} ->
            IO.puts("    Login successful, token generated")

            # Test token validation
            IO.puts("  ✓ Testing token validation...")
            case Grapple.Auth.validate_token(token) do
              {:ok, validated_user} ->
                IO.puts("    Token validated for user: #{validated_user.username}")
              {:error, reason} ->
                issues = issues ++ ["Token validation failed: #{reason}"]
            end

            # Test authorization
            IO.puts("  ✓ Testing authorization...")
            case Grapple.Auth.authorize(user.id, :create_node) do
              :ok ->
                IO.puts("    Authorization check passed")
              {:error, reason} ->
                issues = issues ++ ["Authorization failed: #{reason}"]
            end

            # Test role management
            IO.puts("  ✓ Testing role assignment...")
            case Grapple.Auth.assign_role(user.id, :analytics) do
              {:ok, updated_user} ->
                IO.puts("    Role assigned: #{inspect(updated_user.roles)}")
              {:error, reason} ->
                issues = issues ++ ["Role assignment failed: #{reason}"]
            end

          {:error, reason} ->
            issues = issues ++ ["Login failed: #{reason}"]
        end

        # Cleanup
        Grapple.Auth.delete_user(user.id)

      {:error, reason} ->
        issues = issues ++ ["User registration failed: #{reason}"]
    end

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Search & Indexing
  def audit_search do
    IO.puts("🔍 AUDITING SEARCH & INDEXING\n")
    issues = []

    # Test full-text search
    IO.puts("  ✓ Testing full-text search...")
    {:ok, search_node_id} = Grapple.create_node(%{
      name: "SearchTest",
      description: "This is a searchable description with unique keywords"
    })

    search_properties = %{
      name: "SearchTest",
      description: "This is a searchable description with unique keywords"
    }

    case Grapple.Search.index_node(search_node_id, search_properties) do
      :ok ->
        IO.puts("    Node indexed successfully")

        # Search for indexed content
        case Grapple.Search.search("searchable") do
          {:ok, results} ->
            IO.puts("    Search returned #{length(results)} results")
            if length(results) == 0 do
              issues = issues ++ ["Search returned no results for indexed content"]
            end
          {:error, reason} ->
            issues = issues ++ ["Search failed: #{reason}"]
        end

      {:error, reason} ->
        issues = issues ++ ["Indexing failed: #{reason}"]
    end

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Query Language
  def audit_query_language do
    IO.puts("💬 AUDITING QUERY LANGUAGE\n")
    issues = []

    # Create test data
    {:ok, q1} = Grapple.create_node(%{type: "person", name: "QueryTest1"})
    {:ok, q2} = Grapple.create_node(%{type: "person", name: "QueryTest2"})
    Grapple.create_edge(q1, q2, "knows")

    # Test MATCH query
    IO.puts("  ✓ Testing MATCH query...")
    case Grapple.query("MATCH (n) RETURN n") do
      {:ok, results} ->
        IO.puts("    MATCH query returned #{length(results)} results")
      {:error, reason} ->
        issues = issues ++ ["MATCH query failed: #{reason}"]
    end

    # Test property filter query
    IO.puts("  ✓ Testing property filter query...")
    case Grapple.query("MATCH (n {type: \"person\"}) RETURN n") do
      {:ok, results} ->
        IO.puts("    Property filter returned #{length(results)} results")
      {:error, reason} ->
        issues = issues ++ ["Property filter query failed: #{reason}"]
    end

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Distributed Features
  def audit_distributed do
    IO.puts("🌐 AUDITING DISTRIBUTED FEATURES\n")
    issues = []

    # Test cluster info
    IO.puts("  ✓ Testing cluster info...")
    info = Grapple.cluster_info()
    IO.puts("    Local node: #{info.local_node}")
    IO.puts("    Cluster nodes: #{inspect(info.nodes)}")
    IO.puts("    Partitions: #{info.partitions}")

    # Note: Full distributed testing requires multiple nodes
    IO.puts("    (Skipping multi-node tests - requires distributed setup)")

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Performance Monitoring
  def audit_performance do
    IO.puts("⚡ AUDITING PERFORMANCE MONITORING\n")
    issues = []

    # Test performance monitoring
    IO.puts("  ✓ Testing performance monitor...")
    :ok = Grapple.Performance.Monitor.record_operation(:test_op, 100, :success)
    IO.puts("    Operation recorded")

    metrics = Grapple.Performance.Monitor.get_metrics()
    IO.puts("    Performance metrics: #{inspect(metrics)}")

    # Test profiler
    IO.puts("  ✓ Testing profiler...")
    memory_snapshot = Grapple.Performance.Profiler.get_memory_snapshot()
    IO.puts("    Memory snapshot: #{memory_snapshot.total_memory} bytes total")

    IO.puts("")
    {if(issues == [], do: :pass, else: :fail), issues}
  end

  ## Summary
  defp print_summary(results) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("AUDIT SUMMARY")
    IO.puts(String.duplicate("=", 80) <> "\n")

    total_issues =
      Enum.reduce(results, 0, fn {_category, {_status, issues}}, acc ->
        acc + length(issues)
      end)

    Enum.each(results, fn {category, {status, issues}} ->
      status_icon = if status == :pass, do: "✅", else: "❌"
      IO.puts("#{status_icon} #{String.upcase(to_string(category))}: #{status}")

      if issues != [] do
        Enum.each(issues, fn issue ->
          IO.puts("    - #{issue}")
        end)
      end
    end)

    IO.puts("\nTotal Issues Found: #{total_issues}")
    IO.puts(String.duplicate("=", 80) <> "\n")
  end
end

# Run the audit
GrappleAudit.run()
