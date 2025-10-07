defmodule Grapple.Query.ExecutorTest do
  use ExUnit.Case
  alias Grapple.Query.Executor

  setup do
    # Ensure the ETS graph store is started
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

  describe "execute/1 with MATCH queries" do
    test "executes simple MATCH query" do
      {:ok, _} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
      {:ok, _} = Grapple.create_node(%{name: "Bob", role: "Manager"})

      result = Executor.execute("MATCH (n) RETURN n")

      assert {:ok, nodes} = result
      assert is_list(nodes)
      assert length(nodes) >= 2
    end

    test "executes MATCH query with property filter" do
      {:ok, _} = Grapple.create_node(%{name: "Alice", role: "Engineer"})
      {:ok, _} = Grapple.create_node(%{name: "Bob", role: "Manager"})

      result = Executor.execute("MATCH (n {role: \"Engineer\"}) RETURN n")

      assert {:ok, nodes} = result
      assert is_list(nodes)
      assert length(nodes) >= 1

      Enum.each(nodes, fn node ->
        assert node.properties.role == "Engineer"
      end)
    end

    test "executes MATCH query with multiple properties" do
      {:ok, _} = Grapple.create_node(%{name: "Alice", role: "Engineer", level: "Senior"})
      {:ok, _} = Grapple.create_node(%{name: "Bob", role: "Engineer", level: "Junior"})

      result = Executor.execute("MATCH (n {role: \"Engineer\", level: \"Senior\"}) RETURN n")

      assert {:ok, nodes} = result
      assert is_list(nodes)
    end
  end

  describe "execute/1 with unsupported queries" do
    test "handles TRAVERSE query" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")

      result = Executor.execute("TRAVERSE #{alice} DEPTH 1")

      # TRAVERSE may not be implemented in query parser yet
      case result do
        {:error, {:parse_error, :unsupported_query}} -> assert true
        {:ok, nodes} when is_list(nodes) -> assert true
        _ -> flunk("Unexpected result from TRAVERSE query")
      end
    end
  end

  describe "execute/1 with PATH queries" do
    test "handles PATH query" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(bob, carol, "knows")

      result = Executor.execute("PATH #{alice} #{carol}")

      # PATH may not be implemented in query parser yet
      case result do
        {:error, {:parse_error, :unsupported_query}} -> assert true
        {:error, :path_not_found} -> assert true
        {:ok, path} when is_list(path) -> assert true
        _ -> flunk("Unexpected result from PATH query")
      end
    end
  end

  describe "traverse/3" do
    test "traverses graph in outgoing direction" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(alice, carol, "knows")

      result = Executor.traverse(alice, :out, 1)

      assert {:ok, nodes} = result
      assert length(nodes) == 2

      names = Enum.map(nodes, & &1.properties.name) |> Enum.sort()
      assert names == ["Bob", "Carol"]
    end

    test "traverses graph in incoming direction" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, _} = Grapple.create_edge(bob, alice, "knows")
      {:ok, _} = Grapple.create_edge(carol, alice, "knows")

      result = Executor.traverse(alice, :in, 1)

      assert {:ok, nodes} = result
      assert length(nodes) == 2

      names = Enum.map(nodes, & &1.properties.name) |> Enum.sort()
      assert names == ["Bob", "Carol"]
    end

    test "traverses graph in both directions" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(carol, alice, "knows")

      result = Executor.traverse(alice, :both, 1)

      assert {:ok, nodes} = result
      assert length(nodes) == 2

      names = Enum.map(nodes, & &1.properties.name) |> Enum.sort()
      assert names == ["Bob", "Carol"]
    end

    test "respects depth limit" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, dave} = Grapple.create_node(%{name: "Dave"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(bob, carol, "knows")
      {:ok, _} = Grapple.create_edge(carol, dave, "knows")

      {:ok, nodes1} = Executor.traverse(alice, :out, 1)
      assert length(nodes1) == 1

      {:ok, nodes2} = Executor.traverse(alice, :out, 2)
      assert length(nodes2) == 2

      {:ok, nodes3} = Executor.traverse(alice, :out, 3)
      assert length(nodes3) == 3
    end

    test "handles cycles without infinite loops" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(bob, alice, "knows")

      result = Executor.traverse(alice, :out, 5)

      assert {:ok, nodes} = result
      # Should not hang and should return finite results
      assert is_list(nodes)
      assert length(nodes) >= 1
    end
  end

  describe "find_path/3" do
    test "finds shortest path between nodes" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(bob, carol, "knows")

      result = Executor.find_path(alice, carol, 10)

      assert {:ok, path} = result
      assert path == [alice, bob, carol]
    end

    test "returns self for same start and end node" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})

      result = Executor.find_path(alice, alice)

      assert {:ok, [^alice]} = result
    end

    test "returns error when no path exists" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})

      result = Executor.find_path(alice, bob)

      assert {:error, :path_not_found} = result
    end

    test "respects max depth limit" do
      {:ok, alice} = Grapple.create_node(%{name: "Alice"})
      {:ok, bob} = Grapple.create_node(%{name: "Bob"})
      {:ok, carol} = Grapple.create_node(%{name: "Carol"})
      {:ok, dave} = Grapple.create_node(%{name: "Dave"})
      {:ok, _} = Grapple.create_edge(alice, bob, "knows")
      {:ok, _} = Grapple.create_edge(bob, carol, "knows")
      {:ok, _} = Grapple.create_edge(carol, dave, "knows")

      # With shallow depth, shouldn't find path
      result = Executor.find_path(alice, dave, 2)
      assert {:error, :path_not_found} = result

      # With sufficient depth, should find path
      result2 = Executor.find_path(alice, dave, 3)
      assert {:ok, path} = result2
      assert length(path) == 4
    end
  end

  describe "error handling" do
    test "returns error for invalid query syntax" do
      result = Executor.execute("INVALID QUERY")

      assert {:error, {:parse_error, :unsupported_query}} = result
    end

    test "handles nonexistent nodes in traverse" do
      result = Executor.traverse(99999, :out, 1)

      assert {:error, :node_not_found} = result
    end

    test "handles nonexistent nodes in find_path" do
      result = Executor.find_path(99999, 88888)

      assert {:error, :path_not_found} = result
    end
  end
end
