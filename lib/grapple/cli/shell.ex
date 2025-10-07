defmodule Grapple.CLI.Shell do
  @moduledoc """
  Interactive CLI shell for graph database operations.
  Provides REPL interface for queries and cluster management with comprehensive error handling.
  """

  alias Grapple.Query.Executor
  alias Grapple.Cluster.NodeManager
  alias Grapple.Storage.EtsGraphStore
  alias Grapple.CLI.Autocomplete
  alias Grapple.Visualization.AsciiRenderer

  alias Grapple.Distributed.{
    LifecycleManager,
    ReplicationEngine,
    Orchestrator,
    PersistenceManager
  }

  alias Grapple.Error

  def start do
    IO.puts("Grapple Graph Database Shell")
    IO.puts("Type 'help' for available commands, 'quit' to exit")
    IO.puts("Press TAB for command completion, '?' for suggestions")
    repl_loop()
  end

  defp repl_loop do
    case get_input_with_completion("grapple> ") do
      :eof ->
        IO.puts("\nBye!")

      {:error, reason} ->
        IO.puts("Input error: #{reason}")
        repl_loop()

      input when is_binary(input) ->
        input
        |> String.trim()
        |> handle_command_with_validation()

        repl_loop()

      _ ->
        repl_loop()
    end
  end

  defp handle_command("quit"), do: System.halt(0)
  defp handle_command("exit"), do: System.halt(0)

  defp handle_command("help") do
    IO.puts("""
    Available commands:

    Graph Operations:
      CREATE NODE {prop: value}          - Create a new node
      CREATE EDGE (from)-[label]->(to)   - Create a new edge
      MATCH (n)-[r]->(m)                 - Query graph patterns
      TRAVERSE <node_id> [depth]         - Traverse from node
      PATH <from> <to>                   - Find path between nodes
      VISUALIZE <node_id> [depth]        - ASCII visualization of subgraph
      SHOW GRAPH                         - Show graph statistics
      FIND NODES <prop> <value>          - Find nodes by property
      FIND EDGES <label>                 - Find edges by label

    Distributed Operations:
      CLUSTER STATUS                     - Show distributed cluster status
      CLUSTER JOIN <node>                - Join another cluster node
      CLUSTER HEALTH                     - Show cluster health information
      CLUSTER SHUTDOWN [reason]          - Initiate graceful cluster shutdown
      CLUSTER STARTUP [mode]             - Coordinate cluster startup

    Lifecycle Management:
      LIFECYCLE CLASSIFY <key> <type>    - Classify data lifecycle (ephemeral|computational|session|persistent)
      LIFECYCLE STATS                    - Show lifecycle management statistics
      LIFECYCLE MIGRATE <key> <tier>     - Migrate data to storage tier (ets|mnesia|dets)
      LIFECYCLE POLICIES                 - Show active persistence policies
      LIFECYCLE OPTIMIZE                 - Trigger storage optimization

    Replication Management:
      REPLICA CREATE <key> <policy>      - Create replica set with policy (minimal|balanced|maximum|adaptive)
      REPLICA STATUS <key>               - Show replica health for data key
      REPLICA RESOLVE <key>              - Resolve conflicts for data key
      REPLICA STATS                      - Show replication statistics

    Cluster Operations:
      JOIN <node@host>                   - Join cluster
      CLUSTER INFO                       - Show cluster status
      NODES                              - List cluster nodes

    System:
      help                               - Show this help
      quit/exit                          - Exit shell

    Autocomplete Features:
      TAB                                - Complete current command
      ?                                  - Show all available commands
      <partial>?                         - Show commands matching partial input
    """)
  end

  defp handle_command("CLUSTER INFO") do
    case NodeManager.get_cluster_info() do
      info ->
        IO.puts("Cluster Information:")
        IO.puts("  Local Node: #{info.local_node}")
        IO.puts("  Total Nodes: #{length(info.nodes)}")
        IO.puts("  Nodes: #{Enum.join(info.nodes, ", ")}")
        IO.puts("  Partitions: #{info.partitions}")
    end
  end

  defp handle_command("NODES") do
    info = NodeManager.get_cluster_info()
    IO.puts("Cluster Nodes:")

    Enum.each(info.nodes, fn node ->
      status = if node == info.local_node, do: " (local)", else: ""
      IO.puts("  - #{node}#{status}")
    end)
  end

  defp handle_command("JOIN " <> node_name) do
    node_atom = String.to_atom(String.trim(node_name))

    case NodeManager.join_cluster(node_atom) do
      {:ok, :connected} ->
        IO.puts("Successfully joined cluster node: #{node_atom}")

      {:error, :connection_failed} ->
        IO.puts("Failed to connect to node: #{node_atom}")
    end
  end

  defp handle_command("CREATE NODE " <> props_str) do
    case parse_properties(props_str) do
      {:ok, properties} ->
        case EtsGraphStore.create_node(properties) do
          {:ok, node_id} ->
            IO.puts("✅ Created node with ID: #{node_id}")

          {:error, _reason, _message, _opts} = error ->
            display_error(error)

          {:error, reason} ->
            IO.puts("❌ Error creating node: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Error parsing properties: #{reason}")
    end
  end

  defp handle_command("TRAVERSE " <> args) do
    case String.split(args, " ", trim: true) do
      [node_id_str] ->
        execute_traverse(node_id_str, 1)

      [node_id_str, depth_str] ->
        case Integer.parse(depth_str) do
          {depth, ""} -> execute_traverse(node_id_str, depth)
          _ -> IO.puts("Invalid depth: #{depth_str}")
        end

      _ ->
        IO.puts("Usage: TRAVERSE <node_id> [depth]")
    end
  end

  defp handle_command("PATH " <> args) do
    case String.split(args, " ", trim: true) do
      [from_str, to_str] ->
        case {Integer.parse(from_str), Integer.parse(to_str)} do
          {{from, ""}, {to, ""}} ->
            case Executor.find_path(from, to) do
              {:ok, path} ->
                IO.puts("Path found: #{Enum.join(path, " -> ")}")

              {:error, :path_not_found} ->
                IO.puts("No path found between #{from} and #{to}")
            end

          _ ->
            IO.puts("Invalid node IDs")
        end

      _ ->
        IO.puts("Usage: PATH <from_node_id> <to_node_id>")
    end
  end

  defp handle_command("MATCH " <> query) do
    case Executor.execute("MATCH " <> query) do
      {:ok, results} ->
        IO.puts("Query results:")

        Enum.each(results, fn result ->
          IO.puts("  #{inspect(result)}")
        end)

      {:error, reason} ->
        IO.puts("Query error: #{reason}")
    end
  end

  defp handle_command("VISUALIZE " <> args) do
    case String.split(args, " ", trim: true) do
      [node_id_str] ->
        execute_visualization(node_id_str, 2)

      [node_id_str, depth_str] ->
        case Integer.parse(depth_str) do
          {depth, ""} -> execute_visualization(node_id_str, depth)
          _ -> IO.puts("Invalid depth: #{depth_str}")
        end

      _ ->
        IO.puts("Usage: VISUALIZE <node_id> [depth]")
    end
  end

  defp handle_command("SHOW GRAPH") do
    stats = EtsGraphStore.get_stats()
    IO.puts("Graph Statistics:")
    IO.puts("  Total Nodes: #{stats.total_nodes}")
    IO.puts("  Total Edges: #{stats.total_edges}")
    IO.puts("  Memory Usage:")
    IO.puts("    Nodes: #{stats.memory_usage.nodes} words")
    IO.puts("    Edges: #{stats.memory_usage.edges} words")
    IO.puts("    Indexes: #{stats.memory_usage.indexes} words")
  end

  defp handle_command("CLUSTER STATUS") do
    case Process.whereis(Grapple.Distributed.ClusterManager) do
      nil ->
        IO.puts(
          "Distributed mode not enabled. Start with: Application.put_env(:grapple, :distributed, true)"
        )

      _pid ->
        cluster_info = Grapple.Distributed.ClusterManager.get_cluster_info()
        IO.puts("Distributed Cluster Status:")
        IO.puts("  Local Node: #{cluster_info.local_node}")
        IO.puts("  Cluster Nodes: #{inspect(cluster_info.nodes)}")
        IO.puts("  Partition Count: #{cluster_info.partition_count}")
        IO.puts("  Status: #{cluster_info.status}")
    end
  end

  defp handle_command("CLUSTER HEALTH") do
    case Process.whereis(Grapple.Distributed.HealthMonitor) do
      nil ->
        IO.puts("Health monitoring not available in this mode")

      _pid ->
        health = Grapple.Distributed.HealthMonitor.get_cluster_health()
        IO.puts("Cluster Health Report:")
        IO.puts("  Overall Status: #{health.overall_status}")
        IO.puts("  Monitored Nodes: #{length(health.monitored_nodes)}")
        IO.puts("  Failed Nodes: #{length(health.failed_nodes)}")
        IO.puts("  Recovering Nodes: #{length(health.recovering_nodes)}")

        if length(health.failed_nodes) > 0 do
          IO.puts("  Failed: #{inspect(health.failed_nodes)}")
        end
    end
  end

  defp handle_command("CLUSTER JOIN " <> node_name) do
    case Process.whereis(Grapple.Distributed.ClusterManager) do
      nil ->
        IO.puts("Distributed mode not enabled")

      _pid ->
        target_node = String.to_atom(String.trim(node_name))

        case Grapple.Distributed.ClusterManager.join_cluster(target_node) do
          {:ok, :joined} ->
            IO.puts("Successfully joined cluster at: #{target_node}")

          {:error, reason} ->
            IO.puts("Failed to join cluster: #{inspect(reason)}")
        end
    end
  end

  defp handle_command("CLUSTER SHUTDOWN" <> args) do
    reason =
      case String.trim(args) do
        "" -> :planned
        reason_str -> String.to_atom(reason_str)
      end

    case Process.whereis(Orchestrator) do
      nil ->
        IO.puts("Orchestration not available")

      _pid ->
        IO.puts("🔄 Initiating graceful cluster shutdown...")

        case Orchestrator.initiate_graceful_shutdown(reason) do
          {:ok, :shutdown_complete} ->
            IO.puts("✅ Cluster shutdown completed gracefully")

          {:error, reason} ->
            IO.puts("❌ Shutdown failed: #{inspect(reason)}")
        end
    end
  end

  defp handle_command("CLUSTER STARTUP" <> args) do
    mode =
      case String.trim(args) do
        "" -> :standard
        mode_str -> String.to_atom(mode_str)
      end

    case Process.whereis(Orchestrator) do
      nil ->
        IO.puts("Orchestration not available")

      _pid ->
        IO.puts("🚀 Coordinating cluster startup...")

        case Orchestrator.coordinate_startup(mode) do
          {:ok, :startup_complete} ->
            IO.puts("✅ Cluster startup completed successfully")

          {:error, reason} ->
            IO.puts("❌ Startup failed: #{inspect(reason)}")
        end
    end
  end

  defp handle_command("LIFECYCLE CLASSIFY " <> args) do
    case String.split(args, " ", parts: 2, trim: true) do
      [key, classification_str] ->
        classification = String.to_atom(classification_str)

        case Process.whereis(LifecycleManager) do
          nil ->
            IO.puts("Lifecycle management not available")

          _pid ->
            case LifecycleManager.classify_data(key, classification) do
              {:ok, placement_strategy} ->
                IO.puts("✅ Data classified as #{classification}")
                IO.puts("   Primary node: #{placement_strategy.primary_node}")
                IO.puts("   Replication factor: #{placement_strategy.replication_factor}")
                IO.puts("   Persistence tier: #{placement_strategy.persistence_tier}")

              {:error, reason} ->
                IO.puts("❌ Classification failed: #{inspect(reason)}")
            end
        end

      _ ->
        IO.puts("Usage: LIFECYCLE CLASSIFY <key> <type>")
        IO.puts("Types: ephemeral, computational, session, persistent")
    end
  end

  defp handle_command("LIFECYCLE STATS") do
    case Process.whereis(LifecycleManager) do
      nil ->
        IO.puts("Lifecycle management not available")

      _pid ->
        stats = LifecycleManager.get_lifecycle_stats()
        IO.puts("Lifecycle Management Statistics:")
        IO.puts("  Total classified: #{stats.total_classified}")
        IO.puts("  Classifications:")

        Enum.each(stats.classifications, fn {type, count} ->
          IO.puts("    #{type}: #{count}")
        end)

        IO.puts("  Memory usage: #{stats.memory_usage.total} bytes")
        IO.puts("  Eviction candidates: #{length(stats.eviction_candidates)}")
    end
  end

  defp handle_command("LIFECYCLE MIGRATE " <> args) do
    case String.split(args, " ", parts: 2, trim: true) do
      [key, tier_str] ->
        tier = String.to_atom(tier_str)

        case Process.whereis(PersistenceManager) do
          nil ->
            IO.puts("Persistence management not available")

          _pid ->
            case PersistenceManager.migrate_to_tier(key, tier) do
              {:ok, migration_result} ->
                IO.puts("✅ Migration completed")
                IO.puts("   Data key: #{migration_result.data_key}")
                IO.puts("   From tier: #{migration_result.from_tier}")
                IO.puts("   To tier: #{migration_result.to_tier}")
                IO.puts("   Reason: #{migration_result.reason}")

              {:error, reason} ->
                IO.puts("❌ Migration failed: #{inspect(reason)}")
            end
        end

      _ ->
        IO.puts("Usage: LIFECYCLE MIGRATE <key> <tier>")
        IO.puts("Tiers: ets, mnesia, dets")
    end
  end

  defp handle_command("LIFECYCLE POLICIES") do
    case Process.whereis(PersistenceManager) do
      nil ->
        IO.puts("Persistence management not available")

      _pid ->
        stats = PersistenceManager.get_persistence_stats()
        IO.puts("Persistence Policies:")
        IO.puts("  Active policies: #{stats.active_policies}")
        IO.puts("  Tier utilization:")

        Enum.each(stats.tier_utilization, fn {tier, util} ->
          IO.puts("    #{tier}: #{util.item_count} items, #{div(util.memory_used, 1024)}KB")
        end)

        IO.puts("  Migration queue: #{stats.migration_queue_size} pending")
        IO.puts("  Cost efficiency: #{Float.round(stats.cost_efficiency, 2)} units/item")
    end
  end

  defp handle_command("LIFECYCLE OPTIMIZE") do
    case Process.whereis(PersistenceManager) do
      nil ->
        IO.puts("Persistence management not available")

      _pid ->
        PersistenceManager.optimize_storage_allocation()
        IO.puts("✅ Storage optimization triggered")
    end
  end

  defp handle_command("REPLICA CREATE " <> args) do
    case String.split(args, " ", parts: 2, trim: true) do
      [key, policy_str] ->
        policy = String.to_atom(policy_str)

        case Process.whereis(ReplicationEngine) do
          nil ->
            IO.puts("Replication engine not available")

          _pid ->
            case ReplicationEngine.replicate_data(key, %{key: key}, policy) do
              {:ok, replica_set} ->
                IO.puts("✅ Replica set created")
                IO.puts("   Key: #{replica_set.key}")
                IO.puts("   Primary node: #{replica_set.primary_node}")
                IO.puts("   Replicas: #{length(replica_set.replicas)}")
                IO.puts("   Strategy: #{inspect(replica_set.strategy)}")

              {:error, reason} ->
                IO.puts("❌ Replication failed: #{inspect(reason)}")
            end
        end

      _ ->
        IO.puts("Usage: REPLICA CREATE <key> <policy>")
        IO.puts("Policies: minimal, balanced, maximum, adaptive")
    end
  end

  defp handle_command("REPLICA STATUS " <> key) do
    key = String.trim(key)

    case Process.whereis(ReplicationEngine) do
      nil ->
        IO.puts("Replication engine not available")

      _pid ->
        case ReplicationEngine.get_replica_health(key) do
          {:ok, health} ->
            IO.puts("Replica Health for #{key}:")
            IO.puts("  Total replicas: #{health.total_replicas}")
            IO.puts("  Healthy replicas: #{health.healthy_replicas}")
            IO.puts("  Health ratio: #{Float.round(health.health_ratio * 100, 1)}%")
            IO.puts("  Primary healthy: #{health.primary_healthy}")
            IO.puts("  Conflicts: #{health.conflicts}")

          {:error, reason} ->
            IO.puts("❌ Status check failed: #{inspect(reason)}")
        end
    end
  end

  defp handle_command("REPLICA RESOLVE " <> key) do
    key = String.trim(key)

    case Process.whereis(ReplicationEngine) do
      nil ->
        IO.puts("Replication engine not available")

      _pid ->
        case ReplicationEngine.resolve_conflicts(key) do
          {:ok, resolved_data} ->
            IO.puts("✅ Conflicts resolved for #{key}")
            IO.puts("   Resolved data: #{inspect(resolved_data)}")

          {:error, reason} ->
            IO.puts("❌ Conflict resolution failed: #{inspect(reason)}")
        end
    end
  end

  defp handle_command("REPLICA STATS") do
    case Process.whereis(ReplicationEngine) do
      nil ->
        IO.puts("Replication engine not available")

      _pid ->
        stats = ReplicationEngine.get_replication_stats()
        IO.puts("Replication Statistics:")
        IO.puts("  Total replica sets: #{stats.total_replica_sets}")
        IO.puts("  Consistency level: #{Float.round(stats.consistency_level * 100, 1)}%")

        IO.puts(
          "  Replication efficiency: #{Float.round(stats.replication_efficiency * 100, 1)}%"
        )

        IO.puts("  Conflict rate: #{Float.round(stats.conflict_rate * 100, 2)}%")
        IO.puts("  Recent failover events: #{stats.failover_events}")
    end
  end

  defp handle_command("FIND NODES " <> args) do
    case String.split(args, " ", parts: 2, trim: true) do
      [prop, value] ->
        prop_atom = String.to_atom(prop)
        {:ok, nodes} = EtsGraphStore.find_nodes_by_property(prop_atom, value)

        if length(nodes) > 0 do
          IO.puts("Found #{length(nodes)} nodes:")

          Enum.each(nodes, fn node ->
            IO.puts("  Node #{node.id}: #{inspect(node.properties)}")
          end)
        else
          IO.puts("No nodes found with #{prop}: #{value}")
        end

      _ ->
        IO.puts("Usage: FIND NODES <property> <value>")
    end
  end

  defp handle_command("FIND EDGES " <> label) do
    label = String.trim(label)
    {:ok, edges} = EtsGraphStore.find_edges_by_label(label)

    if length(edges) > 0 do
      IO.puts("Found #{length(edges)} edges with label '#{label}':")

      Enum.each(edges, fn edge ->
        IO.puts("  Edge #{edge.id}: (#{edge.from})-[#{edge.label}]->(#{edge.to})")

        if map_size(edge.properties) > 0 do
          IO.puts("    Properties: #{inspect(edge.properties)}")
        end
      end)
    else
      IO.puts("No edges found with label: #{label}")
    end
  end

  defp handle_command(unknown) do
    suggestions = Autocomplete.suggest_similar_commands(unknown)
    IO.puts("Unknown command: #{unknown}")

    if length(suggestions) > 0 do
      IO.puts("Did you mean:")
      IO.puts(Autocomplete.format_suggestions(suggestions))
    else
      IO.puts("Type 'help' for available commands")
    end
  end

  defp handle_command_with_validation(input) do
    case Autocomplete.validate_command_syntax(input) do
      {:valid, command} ->
        handle_command(command)

      {:invalid, message} ->
        IO.puts("Syntax error: #{message}")
    end
  end

  defp get_input_with_completion(prompt) do
    case IO.gets(prompt) do
      :eof ->
        :eof

      {:error, reason} ->
        {:error, reason}

      input when is_binary(input) ->
        trimmed = String.trim(input)

        cond do
          trimmed == "?" ->
            IO.puts("\n" <> Autocomplete.format_suggestions(Autocomplete.get_completions("")))
            get_input_with_completion(prompt)

          String.ends_with?(trimmed, "?") ->
            partial = String.trim_trailing(trimmed, "?")
            completions = Autocomplete.get_completions(partial)
            IO.puts("\n" <> Autocomplete.format_suggestions(completions))
            get_input_with_completion(prompt)

          String.ends_with?(trimmed, "\t") || String.contains?(trimmed, "\t") ->
            partial = String.replace(trimmed, "\t", "")
            handle_tab_completion(partial, prompt)

          true ->
            trimmed
        end
    end
  end

  defp handle_tab_completion(partial, prompt) do
    case Autocomplete.handle_tab_completion(partial) do
      {:completed, completion} ->
        IO.write("\r#{prompt}#{completion} ")

        case IO.gets("") do
          :eof -> :eof
          {:error, reason} -> {:error, reason}
          additional_input -> completion <> " " <> String.trim(additional_input)
        end

      {:partial, common_prefix} ->
        IO.write("\r#{prompt}#{common_prefix}")
        get_input_with_completion("")

      {:no_completion, _input} ->
        get_input_with_completion(prompt)
    end
  end

  defp execute_traverse(node_id_str, depth) do
    case Integer.parse(node_id_str) do
      {node_id, ""} ->
        case Executor.traverse(node_id, :out, depth) do
          {:ok, nodes} ->
            IO.puts("Traversal results (depth #{depth}):")

            Enum.each(nodes, fn node ->
              IO.puts("  Node #{node.id}: #{inspect(node.properties)}")
            end)

          {:error, reason} ->
            IO.puts("Traversal error: #{reason}")
        end

      _ ->
        IO.puts("Invalid node ID: #{node_id_str}")
    end
  end

  defp execute_visualization(node_id_str, depth) do
    case Integer.parse(node_id_str) do
      {node_id, ""} ->
        case EtsGraphStore.get_node(node_id) do
          {:ok, _node} ->
            visualization = AsciiRenderer.render_subgraph(node_id, depth)
            IO.puts("Graph visualization (depth #{depth}):")
            IO.puts(visualization)

          {:error, :not_found} ->
            IO.puts("Node #{node_id} not found")
        end

      _ ->
        IO.puts("Invalid node ID: #{node_id_str}")
    end
  end

  defp parse_properties(props_str) do
    # Simple property parser for {key: value, key2: value2} format
    try do
      # Remove braces and parse as keyword list
      cleaned =
        props_str |> String.trim() |> String.trim_leading("{") |> String.trim_trailing("}")

      if cleaned == "" do
        {:ok, %{}}
      else
        # Basic parsing - expand for more complex property types
        properties =
          cleaned
          |> String.split(",", trim: true)
          |> Enum.map(fn pair ->
            [key, value] = String.split(pair, ":", parts: 2, trim: true)
            key = key |> String.trim() |> String.to_atom()
            value = value |> String.trim() |> String.trim("\"")
            {key, value}
          end)
          |> Enum.into(%{})

        {:ok, properties}
      end
    rescue
      _ -> {:error, "Invalid property format"}
    end
  end

  defp display_error({:error, reason, message, opts}) do
    IO.puts("❌ #{Error.format_error({:error, reason, message, opts})}")

    suggestions = Error.recovery_suggestions({:error, reason, message, opts})

    if length(suggestions) > 0 do
      IO.puts("\n💡 Suggestions:")

      Enum.each(suggestions, fn suggestion ->
        IO.puts("   • #{suggestion}")
      end)
    end
  end

  defp display_error(error) do
    IO.puts("❌ Error: #{inspect(error)}")
  end
end
