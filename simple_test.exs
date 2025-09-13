#!/usr/bin/env elixir

# Simple test to verify ETS functionality
Code.prepend_path("_build/dev/lib/grapple/ebin")
Application.start(:logger)
{:ok, _} = Grapple.Application.start(nil, nil)

IO.puts("🚀 Grapple ETS Graph Database - Quick Test")
IO.puts("=" |> String.duplicate(40))

# Create test data
{:ok, alice} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
{:ok, bob} = Grapple.create_node(%{name: "Bob", role: "Manager"})
{:ok, _edge} = Grapple.create_edge(alice, bob, "reports_to", %{})

IO.puts("✅ Created nodes and edges")

# Test lookups
{:ok, node} = Grapple.get_node(alice)
IO.puts("✅ Retrieved Alice: #{node.properties.name}")

# Test property search
{:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
IO.puts("✅ Found #{length(engineers)} engineers")

# Test edge search
{:ok, edges} = Grapple.find_edges_by_label("reports_to")
IO.puts("✅ Found #{length(edges)} reporting relationships")

# Test traversal
{:ok, connected} = Grapple.traverse(alice, :out, 1)
IO.puts("✅ Traversed from Alice: #{length(connected)} connected nodes")

# Show stats
stats = Grapple.get_stats()
IO.puts("✅ Stats: #{stats.total_nodes} nodes, #{stats.total_edges} edges")

IO.puts("\n🎉 All basic functionality working!")
IO.puts("\nNow try the CLI:")
IO.puts("  iex -S mix")
IO.puts("  Grapple.start_shell()")