#!/usr/bin/env elixir

# Grapple Quickstart Demo
# This script populates the graph database with sample data
# to demonstrate Grapple's capabilities
#
# Run with: mix run demo/quickstart.exs

defmodule GrappleDemo do
  @moduledoc """
  Quickstart demo script for Grapple Graph Database.

  Creates a sample social network with users, interests, and relationships
  to demonstrate core features including:
  - Node and edge creation
  - Property-based queries
  - Graph traversal
  - Path finding
  - Analytics
  """

  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "╔═══════════════════════════════════════════════════╗")
    IO.puts("║  Grapple Quickstart Demo - Social Network        ║")
    IO.puts("╚═══════════════════════════════════════════════════╝" <> IO.ANSI.reset())
    IO.puts("")

    # Clear any existing data (if using ETS, it's fresh each time)
    IO.puts(IO.ANSI.yellow() <> "📊 Starting with fresh database..." <> IO.ANSI.reset())

    # Create sample data
    users = create_users()
    create_relationships(users)
    create_interests(users)

    # Display statistics
    show_stats()

    # Run example queries
    IO.puts("\n" <> IO.ANSI.cyan() <> "═════════════ Example Queries ═════════════" <> IO.ANSI.reset())
    demonstrate_queries(users)

    # Show next steps
    show_next_steps()

    IO.puts("\n" <> IO.ANSI.green() <> "✅ Demo completed successfully!" <> IO.ANSI.reset())
    IO.puts("")
  end

  defp create_users do
    IO.puts(IO.ANSI.blue() <> "👥 Creating users..." <> IO.ANSI.reset())

    users_data = [
      %{name: "Alice", role: "Engineer", department: "Backend", interests: ["Elixir", "Databases", "Distributed Systems"]},
      %{name: "Bob", role: "Manager", department: "Engineering", interests: ["Leadership", "Agile", "Product"]},
      %{name: "Charlie", role: "Designer", department: "Product", interests: ["UI/UX", "Figma", "Research"]},
      %{name: "Diana", role: "Engineer", department: "Frontend", interests: ["React", "TypeScript", "Design"]},
      %{name: "Eve", role: "Data Scientist", department: "Analytics", interests: ["Machine Learning", "Python", "Statistics"]},
      %{name: "Frank", role: "DevOps", department: "Infrastructure", interests: ["Kubernetes", "AWS", "Monitoring"]},
      %{name: "Grace", role: "Engineer", department: "Backend", interests: ["Elixir", "Phoenix", "GraphQL"]},
      %{name: "Henry", role: "Product Manager", department: "Product", interests: ["Strategy", "Analytics", "User Research"]},
      %{name: "Ivy", role: "Engineer", department: "ML", interests: ["Deep Learning", "PyTorch", "Computer Vision"]},
      %{name: "Jack", role: "Security Engineer", department: "Security", interests: ["Cryptography", "Pentesting", "Compliance"]}
    ]

    users = Enum.map(users_data, fn user_data ->
      {:ok, user_id} = Grapple.create_node(user_data)
      IO.puts("  ✓ Created #{user_data.name} (ID: #{user_id})")
      {user_data.name, user_id}
    end)

    Map.new(users)
  end

  defp create_relationships(users) do
    IO.puts("\n" <> IO.ANSI.blue() <> "🤝 Creating relationships..." <> IO.ANSI.reset())

    # Reporting structure
    relationships = [
      # Management hierarchy
      {users["Alice"], users["Bob"], "reports_to", %{since: "2024-01"}},
      {users["Grace"], users["Bob"], "reports_to", %{since: "2024-03"}},
      {users["Diana"], users["Bob"], "reports_to", %{since: "2023-11"}},
      {users["Eve"], users["Henry"], "reports_to", %{since: "2024-02"}},
      {users["Ivy"], users["Henry"], "reports_to", %{since: "2023-09"}},
      {users["Frank"], users["Bob"], "reports_to", %{since: "2024-01"}},
      {users["Charlie"], users["Henry"], "reports_to", %{since: "2023-08"}},

      # Friendships
      {users["Alice"], users["Grace"], "friends_with", %{since: "2024-01", strength: "strong"}},
      {users["Alice"], users["Diana"], "friends_with", %{since: "2023-12", strength: "medium"}},
      {users["Bob"], users["Henry"], "friends_with", %{since: "2023-06", strength: "strong"}},
      {users["Charlie"], users["Diana"], "friends_with", %{since: "2023-10", strength: "strong"}},
      {users["Eve"], users["Ivy"], "friends_with", %{since: "2023-09", strength: "strong"}},
      {users["Frank"], users["Jack"], "friends_with", %{since: "2024-02", strength: "medium"}},

      # Mentorship
      {users["Alice"], users["Grace"], "mentors", %{area: "Backend Development", since: "2024-03"}},
      {users["Bob"], users["Alice"], "mentors", %{area: "Leadership", since: "2024-01"}},
      {users["Eve"], users["Ivy"], "mentors", %{area: "Machine Learning", since: "2023-09"}},
      {users["Diana"], users["Charlie"], "mentors", %{area: "Frontend Best Practices", since: "2024-01"}},

      # Collaboration
      {users["Alice"], users["Frank"], "collaborates_with", %{project: "Infrastructure"}},
      {users["Grace"], users["Diana"], "collaborates_with", %{project: "API Gateway"}},
      {users["Eve"], users["Ivy"], "collaborates_with", %{project: "Recommendation Engine"}},
      {users["Charlie"], users["Henry"], "collaborates_with", %{project: "Product Redesign"}},
      {users["Frank"], users["Jack"], "collaborates_with", %{project: "Security Audit"}},
    ]

    Enum.each(relationships, fn {from, to, label, props} ->
      {:ok, _edge_id} = Grapple.create_edge(from, to, label, props)
    end)

    IO.puts("  ✓ Created #{length(relationships)} relationships")
  end

  defp create_interests(users) do
    IO.puts("\n" <> IO.ANSI.blue() <> "🎯 Creating interest connections..." <> IO.ANSI.reset())

    # Create nodes for interests/technologies
    interests = [
      "Elixir", "Databases", "Distributed Systems", "Leadership", "Agile",
      "Product", "UI/UX", "Figma", "Research", "React", "TypeScript",
      "Design", "Machine Learning", "Python", "Statistics", "Kubernetes",
      "AWS", "Monitoring", "Phoenix", "GraphQL", "Deep Learning", "PyTorch",
      "Computer Vision", "Cryptography", "Pentesting", "Compliance", "Strategy",
      "Analytics", "User Research"
    ]

    interest_nodes = Enum.map(interests, fn interest ->
      {:ok, interest_id} = Grapple.create_node(%{type: "interest", name: interest})
      {interest, interest_id}
    end) |> Map.new()

    # Connect users to their interests
    Enum.each(users, fn {_name, user_id} ->
      {:ok, node} = Grapple.get_node(user_id)
      user_interests = Map.get(node.properties, :interests, [])

      Enum.each(user_interests, fn interest ->
        if Map.has_key?(interest_nodes, interest) do
          {:ok, _} = Grapple.create_edge(
            user_id,
            interest_nodes[interest],
            "interested_in",
            %{level: Enum.random(["beginner", "intermediate", "expert"])}
          )
        end
      end)
    end)

    IO.puts("  ✓ Created #{map_size(interest_nodes)} interest nodes")
    IO.puts("  ✓ Connected users to their interests")
  end

  defp show_stats do
    stats = Grapple.get_stats()

    IO.puts("\n" <> IO.ANSI.green() <> "═════════════ Database Statistics ═════════════" <> IO.ANSI.reset())
    IO.puts("  📊 Total Nodes: #{IO.ANSI.yellow()}#{stats.total_nodes}#{IO.ANSI.reset()}")
    IO.puts("  🔗 Total Edges: #{IO.ANSI.yellow()}#{stats.total_edges}#{IO.ANSI.reset()}")

    if Map.has_key?(stats, :memory_usage) do
      memory = stats.memory_usage
      IO.puts("\n  💾 Memory Usage:")
      IO.puts("     Nodes:   #{format_memory(memory.nodes)}")
      IO.puts("     Edges:   #{format_memory(memory.edges)}")
      IO.puts("     Indexes: #{format_memory(memory.indexes)}")
    end
  end

  defp format_memory(words) when is_integer(words) do
    bytes = words * :erlang.system_info(:wordsize)
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{Float.round(bytes / 1024 / 1024, 2)} MB"
    end
  end

  defp demonstrate_queries(users) do
    IO.puts("")

    # Query 1: Find all engineers
    IO.puts(IO.ANSI.cyan() <> "1. Find all Engineers:" <> IO.ANSI.reset())
    {:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
    IO.puts("   Found #{length(engineers)} engineers:")
    Enum.each(engineers, fn node ->
      IO.puts("     • #{node.properties.name} (#{node.properties.department})")
    end)

    # Query 2: Find reporting relationships
    IO.puts("\n" <> IO.ANSI.cyan() <> "2. Find reporting relationships:" <> IO.ANSI.reset())
    {:ok, reports} = Grapple.find_edges_by_label("reports_to")
    IO.puts("   Found #{length(reports)} direct reports")
    Enum.take(reports, 3) |> Enum.each(fn edge ->
      {:ok, from_node} = Grapple.get_node(edge.from)
      {:ok, to_node} = Grapple.get_node(edge.to)
      IO.puts("     • #{from_node.properties.name} → #{to_node.properties.name} (since #{edge.properties.since})")
    end)
    if length(reports) > 3, do: IO.puts("     ... and #{length(reports) - 3} more")

    # Query 3: Traverse from Alice
    alice_id = users["Alice"]
    IO.puts("\n" <> IO.ANSI.cyan() <> "3. Traverse from Alice (depth 2, outgoing):" <> IO.ANSI.reset())
    {:ok, neighbors} = Grapple.traverse(alice_id, :out, 2)
    IO.puts("   Found #{length(neighbors)} connected nodes:")
    Enum.take(neighbors, 5) |> Enum.each(fn node ->
      name = Map.get(node.properties, :name, Map.get(node.properties, :type, "Unknown"))
      IO.puts("     • #{name}")
    end)
    if length(neighbors) > 5, do: IO.puts("     ... and #{length(neighbors) - 5} more")

    # Query 4: Find path between Alice and Henry
    alice_id = users["Alice"]
    henry_id = users["Henry"]
    IO.puts("\n" <> IO.ANSI.cyan() <> "4. Find shortest path (Alice → Henry):" <> IO.ANSI.reset())
    case Grapple.find_path(alice_id, henry_id) do
      {:ok, path} ->
        IO.puts("   Path length: #{length(path)} nodes")
        path_names = Enum.map(path, fn node_id ->
          {:ok, node} = Grapple.get_node(node_id)
          node.properties.name
        end)
        IO.puts("   Path: #{Enum.join(path_names, " → ")}")
      {:error, :path_not_found} ->
        IO.puts("   No path found")
    end

    # Query 5: Find all mentorship relationships
    IO.puts("\n" <> IO.ANSI.cyan() <> "5. Find mentorship relationships:" <> IO.ANSI.reset())
    {:ok, mentorships} = Grapple.find_edges_by_label("mentors")
    IO.puts("   Found #{length(mentorships)} mentorship relationships:")
    Enum.each(mentorships, fn edge ->
      {:ok, mentor} = Grapple.get_node(edge.from)
      {:ok, mentee} = Grapple.get_node(edge.to)
      IO.puts("     • #{mentor.properties.name} → #{mentee.properties.name} (#{edge.properties.area})")
    end)

    # Query 6: Find Backend department members
    IO.puts("\n" <> IO.ANSI.cyan() <> "6. Find Backend department members:" <> IO.ANSI.reset())
    {:ok, backend_team} = Grapple.find_nodes_by_property(:department, "Backend")
    IO.puts("   Found #{length(backend_team)} Backend team members:")
    Enum.each(backend_team, fn node ->
      IO.puts("     • #{node.properties.name} (#{node.properties.role})")
    end)
  end

  defp show_next_steps do
    IO.puts("\n" <> IO.ANSI.magenta() <> "═════════════ Next Steps ═════════════" <> IO.ANSI.reset())
    IO.puts("")
    IO.puts("🚀 " <> IO.ANSI.cyan() <> "Explore the Interactive CLI:" <> IO.ANSI.reset())
    IO.puts("   $ iex -S mix")
    IO.puts("   iex> Grapple.start_shell()")
    IO.puts("")
    IO.puts("📊 " <> IO.ANSI.cyan() <> "Try Some Queries:" <> IO.ANSI.reset())
    IO.puts("   # Find all friends")
    IO.puts("   {:ok, friends} = Grapple.find_edges_by_label(\"friends_with\")")
    IO.puts("")
    IO.puts("   # Explore collaborations")
    IO.puts("   {:ok, collabs} = Grapple.find_edges_by_label(\"collaborates_with\")")
    IO.puts("")
    IO.puts("   # Find nodes by interest")
    IO.puts("   {:ok, interests} = Grapple.find_nodes_by_property(:type, \"interest\")")
    IO.puts("")
    IO.puts("🔍 " <> IO.ANSI.cyan() <> "Run Analytics:" <> IO.ANSI.reset())
    IO.puts("   {:ok, summary} = Grapple.Analytics.summary()")
    IO.puts("   {:ok, pageranks} = Grapple.Analytics.pagerank()")
    IO.puts("   {:ok, components} = Grapple.Analytics.connected_components()")
    IO.puts("")
    IO.puts("🌐 " <> IO.ANSI.cyan() <> "Start the Web UI:" <> IO.ANSI.reset())
    IO.puts("   $ mix phx.server")
    IO.puts("   Then visit: http://localhost:4000")
    IO.puts("")
    IO.puts("📖 " <> IO.ANSI.cyan() <> "Read the Guide:" <> IO.ANSI.reset())
    IO.puts("   See QUICKSTART.md for detailed tutorials and examples")
    IO.puts("")
  end
end

# Run the demo
GrappleDemo.run()
