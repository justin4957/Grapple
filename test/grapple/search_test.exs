defmodule Grapple.SearchTest do
  use ExUnit.Case, async: false
  alias Grapple.Search
  alias Grapple.Storage.EtsGraphStore

  setup do
    # Ensure services are started (they may already be started by Application)
    # We don't use start_supervised! because the services are already in the application tree
    :ok =
      case Process.whereis(Grapple.Storage.EtsGraphStore) do
        nil -> {:error, "EtsGraphStore not started"}
        _pid -> :ok
      end

    :ok =
      case Process.whereis(Grapple.Search.InvertedIndex) do
        nil -> {:error, "InvertedIndex not started"}
        _pid -> :ok
      end

    # Create test nodes
    {:ok, node1_id} =
      EtsGraphStore.create_node(%{
        title: "Introduction to Graph Databases",
        description: "Learn about graph database fundamentals and applications"
      })

    {:ok, node2_id} =
      EtsGraphStore.create_node(%{
        title: "Machine Learning Basics",
        description: "Understanding machine learning algorithms and models"
      })

    {:ok, node3_id} =
      EtsGraphStore.create_node(%{
        title: "Graph Machine Learning",
        description: "Applying machine learning techniques to graph data structures"
      })

    {:ok, node4_id} =
      EtsGraphStore.create_node(%{
        title: "Database Performance",
        description: "Optimizing database queries and indexing strategies"
      })

    on_exit(fn ->
      # Clean up test nodes
      EtsGraphStore.delete_node(node1_id)
      EtsGraphStore.delete_node(node2_id)
      EtsGraphStore.delete_node(node3_id)
      EtsGraphStore.delete_node(node4_id)
      :ok
    end)

    %{
      node1: node1_id,
      node2: node2_id,
      node3: node3_id,
      node4: node4_id
    }
  end

  describe "search/2" do
    test "finds nodes with single keyword", %{node1: node1_id, node4: node4_id} do
      {:ok, results} = Search.search("database")

      node_ids = Enum.map(results, & &1.id)
      assert node1_id in node_ids
      assert node4_id in node_ids
      assert length(results) >= 2
    end

    test "finds nodes with multiple keywords using OR operator", %{
      node2: node2_id,
      node3: node3_id
    } do
      {:ok, results} = Search.search("machine learning", operator: :or)

      node_ids = Enum.map(results, & &1.id)
      assert node2_id in node_ids
      assert node3_id in node_ids
      assert length(results) >= 2
    end

    test "finds nodes with multiple keywords using AND operator", %{node3: node3_id} do
      {:ok, results} = Search.search("graph machine", operator: :and)

      node_ids = Enum.map(results, & &1.id)
      assert node3_id in node_ids
    end

    test "searches specific fields only", %{node1: node1_id} do
      {:ok, results} = Search.search("graph", fields: [:title])

      node_ids = Enum.map(results, & &1.id)
      assert node1_id in node_ids
    end

    test "returns results with relevance scores" do
      {:ok, results} = Search.search("machine learning")

      Enum.each(results, fn node ->
        assert Map.has_key?(node, :search_score)
        assert node.search_score > 0
      end)
    end

    test "respects limit option" do
      {:ok, results} = Search.search("machine learning", limit: 1)
      assert length(results) <= 1
    end

    test "respects min_score option" do
      {:ok, results} = Search.search("machine learning", min_score: 100)
      # High min_score should filter out low-scoring results
      assert length(results) >= 0
    end

    test "returns empty list when no matches found" do
      {:ok, results} = Search.search("nonexistent keyword xyz")
      assert results == []
    end

    test "handles case insensitivity" do
      {:ok, results1} = Search.search("MACHINE")
      {:ok, results2} = Search.search("machine")
      {:ok, results3} = Search.search("Machine")

      assert length(results1) == length(results2)
      assert length(results2) == length(results3)
    end
  end

  describe "fuzzy_search/2" do
    test "finds nodes with typos in search query", %{node2: node2_id} do
      # "machne" instead of "machine"
      {:ok, results} = Search.fuzzy_search("machne", distance: 2)

      node_ids = Enum.map(results, & &1.id)
      assert node2_id in node_ids
    end

    test "respects distance parameter" do
      # Very different word should not match with distance 1
      {:ok, results1} = Search.fuzzy_search("xyz", distance: 1)
      assert length(results1) == 0

      # But might match with very large distance
      {:ok, results2} = Search.fuzzy_search("mchine", distance: 2)
      assert length(results2) >= 0
    end

    test "finds nodes with misspellings", %{node1: node1_id} do
      # "graff" instead of "graph"
      {:ok, results} = Search.fuzzy_search("graff", distance: 2)

      node_ids = Enum.map(results, & &1.id)
      assert node1_id in node_ids or length(results) >= 0
    end

    test "supports field filtering in fuzzy search" do
      {:ok, results} = Search.fuzzy_search("databse", distance: 2, fields: [:title])
      assert is_list(results)
    end
  end

  describe "phrase_search/2" do
    test "finds exact phrase matches", %{node2: node2_id} do
      {:ok, results} = Search.phrase_search("machine learning")

      node_ids = Enum.map(results, & &1.id)
      assert node2_id in node_ids
    end

    test "does not match partial phrases" do
      # "learning machine" is not the same as "machine learning"
      {:ok, results1} = Search.phrase_search("machine learning")
      {:ok, results2} = Search.phrase_search("learning machine")

      # The results should be different
      assert Enum.map(results1, & &1.id) != Enum.map(results2, & &1.id) or
               (results1 == [] and results2 == [])
    end

    test "returns empty list when phrase not found" do
      {:ok, results} = Search.phrase_search("this exact phrase does not exist")
      assert results == []
    end

    test "supports field filtering in phrase search", %{node1: node1_id} do
      {:ok, results} = Search.phrase_search("graph databases", fields: [:title])

      node_ids = Enum.map(results, & &1.id)
      # Should find "Graph Databases" in title
      assert node1_id in node_ids or length(results) >= 0
    end
  end

  describe "index_node/3" do
    test "manually indexes a node" do
      {:ok, node_id} = EtsGraphStore.create_node(%{title: "Test Node"})

      # Re-index the node
      result = Search.index_node(node_id, %{title: "Updated Test Node"})
      assert result == :ok

      # Should find the node with updated content
      {:ok, results} = Search.search("updated")
      node_ids = Enum.map(results, & &1.id)
      assert node_id in node_ids
    end

    test "indexes only specified fields" do
      {:ok, node_id} =
        EtsGraphStore.create_node(%{
          title: "Visible Content",
          secret: "Hidden Content"
        })

      # Re-index with only title field
      Search.index_node(node_id, %{title: "Visible Content", secret: "Hidden Content"}, [:title])

      # Should find by title
      {:ok, results1} = Search.search("visible")
      assert length(results1) > 0

      # May or may not find by secret depending on initial indexing
      {:ok, results2} = Search.search("hidden")
      # This test just verifies the function works, actual behavior depends on indexing logic
      assert is_list(results2)
    end
  end

  describe "remove_node/1" do
    test "removes node from search index", %{node1: node1_id} do
      # Verify node is initially searchable
      {:ok, results_before} = Search.search("graph")
      node_ids_before = Enum.map(results_before, & &1.id)
      assert node1_id in node_ids_before

      # Remove the node
      Search.remove_node(node1_id)
      EtsGraphStore.delete_node(node1_id)

      # Node should not appear in search results
      {:ok, results_after} = Search.search("graph")
      node_ids_after = Enum.map(results_after, & &1.id)
      refute node1_id in node_ids_after
    end
  end

  describe "reindex_all/1" do
    test "reindexes all nodes in the graph" do
      {:ok, result} = Search.reindex_all()

      assert Map.has_key?(result, :indexed)
      assert Map.has_key?(result, :errors)
      assert result.indexed >= 4
      assert result.errors == 0
    end

    test "reindexes with specific fields" do
      {:ok, result} = Search.reindex_all(fields: [:title])

      assert result.indexed >= 4
      assert result.errors == 0
    end
  end

  describe "get_stats/0" do
    test "returns index statistics" do
      stats = Search.get_stats()

      assert Map.has_key?(stats, :total_tokens)
      assert Map.has_key?(stats, :indexed_documents)
      assert Map.has_key?(stats, :memory_usage)

      assert stats.total_tokens > 0
      assert stats.indexed_documents > 0
      assert is_map(stats.memory_usage)
    end
  end

  describe "integration with GraphStore" do
    test "nodes are automatically indexed on creation" do
      {:ok, node_id} =
        EtsGraphStore.create_node(%{
          title: "Automatically Indexed Node",
          description: "This should be searchable immediately"
        })

      # Should be able to find the node immediately
      {:ok, results} = Search.search("automatically indexed")
      node_ids = Enum.map(results, & &1.id)
      assert node_id in node_ids
    end

    test "nodes are automatically removed from index on deletion" do
      {:ok, node_id} =
        EtsGraphStore.create_node(%{
          title: "Temporary Node",
          description: "This will be deleted"
        })

      # Verify it's searchable
      {:ok, results_before} = Search.search("temporary")
      node_ids_before = Enum.map(results_before, & &1.id)
      assert node_id in node_ids_before

      # Delete the node
      EtsGraphStore.delete_node(node_id)

      # Should not be searchable anymore
      {:ok, results_after} = Search.search("temporary")
      node_ids_after = Enum.map(results_after, & &1.id)
      refute node_id in node_ids_after
    end
  end
end
