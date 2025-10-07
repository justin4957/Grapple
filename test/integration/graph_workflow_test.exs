defmodule Grapple.Integration.GraphWorkflowTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  setup do
    # Ensure all required services are started
    Application.ensure_all_started(:grapple)

    case Grapple.Storage.EtsGraphStore.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Clear any existing data
    try do
      :ets.delete_all_objects(:grapple_nodes)
      :ets.delete_all_objects(:grapple_edges)
      :ets.delete_all_objects(:grapple_node_edges_out)
      :ets.delete_all_objects(:grapple_node_edges_in)
      :ets.delete_all_objects(:grapple_property_index)
      :ets.delete_all_objects(:grapple_label_index)
    catch
      _ -> :ok
    end

    :ok
  end

  describe "complete graph workflow" do
    test "end-to-end social network scenario" do
      # 1. Create users
      {:ok, alice_id} =
        Grapple.create_node(%{
          name: "Alice",
          role: "Engineer",
          department: "Backend",
          email: "alice@example.com"
        })

      {:ok, bob_id} =
        Grapple.create_node(%{
          name: "Bob",
          role: "Engineer",
          department: "Frontend",
          email: "bob@example.com"
        })

      {:ok, carol_id} =
        Grapple.create_node(%{
          name: "Carol",
          role: "Manager",
          department: "Engineering",
          email: "carol@example.com"
        })

      {:ok, dave_id} =
        Grapple.create_node(%{
          name: "Dave",
          role: "Designer",
          department: "Product",
          email: "dave@example.com"
        })

      # 2. Create relationships
      {:ok, _} =
        Grapple.create_edge(alice_id, bob_id, "knows", %{since: "2020", strength: "strong"})

      {:ok, _} = Grapple.create_edge(bob_id, carol_id, "reports_to", %{since: "2021"})
      {:ok, _} = Grapple.create_edge(alice_id, carol_id, "reports_to", %{since: "2019"})
      {:ok, _} = Grapple.create_edge(alice_id, dave_id, "collaborates_with", %{projects: 5})
      {:ok, _} = Grapple.create_edge(dave_id, carol_id, "reports_to", %{since: "2022"})

      # 3. Query by properties
      {:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
      assert length(engineers) == 2
      engineer_names = Enum.map(engineers, & &1.properties.name) |> Enum.sort()
      assert engineer_names == ["Alice", "Bob"]

      {:ok, backend_engineers} = Grapple.find_nodes_by_property(:department, "Backend")
      assert length(backend_engineers) == 1
      assert hd(backend_engineers).properties.name == "Alice"

      # 4. Find relationships
      {:ok, reports_to_edges} = Grapple.find_edges_by_label("reports_to")
      assert length(reports_to_edges) == 3

      {:ok, knows_edges} = Grapple.find_edges_by_label("knows")
      assert length(knows_edges) == 1

      # 5. Traverse relationships
      {:ok, alice_connections} = Grapple.traverse(alice_id, :out, 1)
      assert length(alice_connections) == 3
      connection_names = Enum.map(alice_connections, & &1.properties.name) |> Enum.sort()
      assert connection_names == ["Bob", "Carol", "Dave"]

      # 6. Find paths
      {:ok, path_to_carol} = Grapple.find_path(alice_id, carol_id)
      assert length(path_to_carol) == 2
      assert path_to_carol == [alice_id, carol_id]

      {:ok, path_alice_to_dave} = Grapple.find_path(alice_id, dave_id)
      assert alice_id in path_alice_to_dave
      assert dave_id in path_alice_to_dave

      # 7. Check statistics
      stats = Grapple.get_stats()
      assert stats.total_nodes >= 4
      assert stats.total_edges >= 5
      assert stats.memory_usage.nodes > 0
      assert stats.memory_usage.edges > 0

      # 8. Query using query language
      {:ok, all_nodes} = Grapple.query("MATCH (n) RETURN n")
      assert length(all_nodes) >= 4

      {:ok, engineers_query} = Grapple.query("MATCH (n {role: \"Engineer\"}) RETURN n")
      assert length(engineers_query) == 2

      # 9. Multi-hop traversal
      {:ok, two_hop} = Grapple.traverse(bob_id, :out, 2)
      # Bob -> Carol is one hop, might reach further nodes at 2 hops
      assert is_list(two_hop)

      # 10. Verify data integrity
      {:ok, alice} = Grapple.get_node(alice_id)
      assert alice.properties.name == "Alice"
      assert alice.properties.role == "Engineer"

      {:ok, carol} = Grapple.get_node(carol_id)
      assert carol.properties.role == "Manager"
    end

    test "complete project management workflow" do
      # Create project nodes
      {:ok, project1} =
        Grapple.create_node(%{
          type: "project",
          name: "Project Alpha",
          status: "active",
          priority: "high"
        })

      {:ok, _project2} =
        Grapple.create_node(%{
          type: "project",
          name: "Project Beta",
          status: "planning",
          priority: "medium"
        })

      # Create task nodes
      {:ok, task1} =
        Grapple.create_node(%{
          type: "task",
          title: "Design database schema",
          status: "done"
        })

      {:ok, task2} =
        Grapple.create_node(%{
          type: "task",
          title: "Implement API endpoints",
          status: "in_progress"
        })

      {:ok, task3} =
        Grapple.create_node(%{
          type: "task",
          title: "Write tests",
          status: "todo"
        })

      # Create person nodes
      {:ok, person1} =
        Grapple.create_node(%{
          type: "person",
          name: "John",
          role: "Developer"
        })

      {:ok, person2} =
        Grapple.create_node(%{
          type: "person",
          name: "Jane",
          role: "QA Engineer"
        })

      # Create relationships
      {:ok, _} = Grapple.create_edge(project1, task1, "contains")
      {:ok, _} = Grapple.create_edge(project1, task2, "contains")
      {:ok, _} = Grapple.create_edge(project1, task3, "contains")
      {:ok, _} = Grapple.create_edge(task2, task3, "blocks")
      {:ok, _} = Grapple.create_edge(person1, task1, "completed")
      {:ok, _} = Grapple.create_edge(person1, task2, "assigned_to")
      {:ok, _} = Grapple.create_edge(person2, task3, "assigned_to")

      # Query: Find all tasks in Project Alpha
      {:ok, project1_tasks} = Grapple.traverse(project1, :out, 1)
      assert length(project1_tasks) == 3

      task_titles = Enum.map(project1_tasks, & &1.properties.title) |> Enum.sort()

      assert "Design database schema" in task_titles
      assert "Implement API endpoints" in task_titles
      assert "Write tests" in task_titles

      # Query: Find all active projects
      {:ok, active_projects} = Grapple.find_nodes_by_property(:status, "active")
      assert length(active_projects) >= 1
      assert Enum.any?(active_projects, fn p -> p.properties.name == "Project Alpha" end)

      # Query: Find all tasks assigned to John
      {:ok, john_edges} = Grapple.find_edges_by_label("assigned_to")
      john_task_edges = Enum.filter(john_edges, fn edge -> edge.from == person1 end)
      assert length(john_task_edges) == 1

      # Query: Find blocked tasks
      {:ok, blocking_edges} = Grapple.find_edges_by_label("blocks")
      assert length(blocking_edges) == 1

      # Verify statistics
      stats = Grapple.get_stats()
      assert stats.total_nodes >= 7
      assert stats.total_edges >= 7
    end

    test "knowledge graph workflow" do
      # Create concept nodes
      {:ok, elixir} =
        Grapple.create_node(%{
          type: "language",
          name: "Elixir",
          paradigm: "functional"
        })

      {:ok, erlang} =
        Grapple.create_node(%{
          type: "language",
          name: "Erlang",
          paradigm: "functional"
        })

      {:ok, beam} =
        Grapple.create_node(%{
          type: "vm",
          name: "BEAM",
          description: "Erlang Virtual Machine"
        })

      {:ok, otp} =
        Grapple.create_node(%{
          type: "framework",
          name: "OTP",
          description: "Open Telecom Platform"
        })

      {:ok, phoenix} =
        Grapple.create_node(%{
          type: "framework",
          name: "Phoenix",
          description: "Web framework for Elixir"
        })

      # Create relationships
      {:ok, _} = Grapple.create_edge(elixir, beam, "runs_on")
      {:ok, _} = Grapple.create_edge(erlang, beam, "runs_on")
      {:ok, _} = Grapple.create_edge(elixir, erlang, "built_on")
      {:ok, _} = Grapple.create_edge(elixir, otp, "uses")
      {:ok, _} = Grapple.create_edge(phoenix, elixir, "built_with")
      {:ok, _} = Grapple.create_edge(phoenix, otp, "uses")

      # Query: What does Elixir run on?
      {:ok, elixir_deps} = Grapple.traverse(elixir, :out, 1)
      dep_names = Enum.map(elixir_deps, & &1.properties.name) |> Enum.sort()
      assert "BEAM" in dep_names
      assert "Erlang" in dep_names

      # Query: What languages run on BEAM?
      {:ok, beam_langs} = Grapple.traverse(beam, :in, 1)
      lang_names = Enum.map(beam_langs, & &1.properties.name) |> Enum.sort()
      assert "Elixir" in lang_names
      assert "Erlang" in lang_names

      # Query: Transitive dependencies of Phoenix
      {:ok, phoenix_deps_1hop} = Grapple.traverse(phoenix, :out, 1)
      {:ok, phoenix_deps_2hop} = Grapple.traverse(phoenix, :out, 2)

      assert length(phoenix_deps_2hop) >= length(phoenix_deps_1hop)

      # Query: Path from Phoenix to BEAM
      {:ok, path} = Grapple.find_path(phoenix, beam)
      assert phoenix in path
      assert beam in path
      assert length(path) >= 2

      # Query: Find all functional languages
      {:ok, functional_langs} = Grapple.find_nodes_by_property(:paradigm, "functional")
      assert length(functional_langs) >= 2
    end
  end

  describe "performance under load" do
    test "handles bulk operations efficiently" do
      start_time = System.monotonic_time(:millisecond)

      # Create 1000 nodes
      node_ids =
        Enum.map(1..1000, fn i ->
          {:ok, id} =
            Grapple.create_node(%{
              id: i,
              name: "Node#{i}",
              category: "bulk_test",
              value: i * 100
            })

          id
        end)

      # Create 2000 edges
      Enum.each(0..1999, fn i ->
        from = Enum.at(node_ids, rem(i, 1000))
        to = Enum.at(node_ids, rem(i + 1, 1000))
        Grapple.create_edge(from, to, "connects", %{weight: i})
      end)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete in reasonable time (< 5 seconds)
      assert duration < 5000

      # Verify data was created
      stats = Grapple.get_stats()
      assert stats.total_nodes >= 1000
      assert stats.total_edges >= 2000

      # Query should still be fast
      query_start = System.monotonic_time(:millisecond)
      {:ok, bulk_nodes} = Grapple.find_nodes_by_property(:category, "bulk_test")
      query_end = System.monotonic_time(:millisecond)
      query_duration = query_end - query_start

      assert length(bulk_nodes) == 1000
      # Query should be fast (< 100ms)
      assert query_duration < 100
    end
  end
end
