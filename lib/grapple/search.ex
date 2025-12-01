defmodule Grapple.Search do
  @moduledoc """
  Full-text search capabilities for Grapple graph database.

  Provides powerful text search functionality including:
  - Basic text search with AND/OR operators
  - Fuzzy search with edit distance tolerance
  - Phrase search for exact matches
  - Multi-field search support
  - Relevance scoring

  ## Quick Start

      # 1. Create a node with searchable content
      {:ok, node_id} = Grapple.create_node(%{
        title: "Graph Databases",
        description: "A comprehensive guide to graph databases and their applications"
      })

      # 2. Index the node for search (fetches properties automatically)
      :ok = Grapple.Search.index_node(node_id)

      # Or index specific fields only
      :ok = Grapple.Search.index_node(node_id, [:title, :description])

      # 3. Search indexed content
      {:ok, results} = Grapple.Search.search("graph databases")

  ## Search Examples

      # Basic text search
      {:ok, nodes} = Grapple.Search.search("machine learning")

      # Search specific fields
      {:ok, nodes} = Grapple.Search.search("graph database", fields: [:title, :description])

      # Fuzzy search with typo tolerance
      {:ok, nodes} = Grapple.Search.fuzzy_search("machne lernin", distance: 2)

      # Phrase search for exact matches
      {:ok, nodes} = Grapple.Search.phrase_search("exact phrase")

      # Search with AND operator (all terms must match)
      {:ok, nodes} = Grapple.Search.search("machine learning", operator: :and)

  ## Indexing Options

      # Index with explicit properties (for custom property maps)
      Grapple.Search.index_node_with_properties(node_id, %{
        title: "Custom Title",
        description: "Custom description"
      }, [:title, :description])

      # Re-index all nodes in the graph
      {:ok, %{indexed: 150, errors: 0}} = Grapple.Search.reindex_all()

      # Get search index statistics
      stats = Grapple.Search.get_stats()
  """

  alias Grapple.Storage.EtsGraphStore
  alias Grapple.Search.InvertedIndex

  @doc """
  Searches for nodes containing the given text.

  ## Parameters

    * `query` - The search query string
    * `opts` - Search options
      * `:fields` - List of fields to search in (default: all indexed fields)
      * `:operator` - Boolean operator `:and` or `:or` (default: `:or`)
      * `:limit` - Maximum number of results to return (default: 100)
      * `:min_score` - Minimum relevance score (default: 0)
      * `:analyzer_options` - Options for text analysis

  ## Returns

  `{:ok, nodes}` where nodes is a list of node data sorted by relevance score.

  ## Examples

      iex> {:ok, nodes} = Grapple.Search.search("machine learning")
      iex> length(nodes)
      5

      iex> {:ok, nodes} = Grapple.Search.search("graph", fields: [:title], operator: :and)
      {:ok, [...]}
  """
  def search(query, opts \\ []) when is_binary(query) do
    case InvertedIndex.search(query, opts) do
      {:ok, scores} ->
        nodes = fetch_and_sort_nodes(scores, opts)
        {:ok, nodes}

      error ->
        error
    end
  end

  @doc """
  Performs fuzzy search with tolerance for typos and misspellings.

  ## Parameters

    * `query` - The search query string
    * `opts` - Search options
      * `:distance` - Maximum Levenshtein distance (default: 2)
      * `:fields` - List of fields to search in
      * `:operator` - Boolean operator `:and` or `:or` (default: `:or`)
      * `:limit` - Maximum number of results to return (default: 100)
      * `:min_score` - Minimum relevance score (default: 0)

  ## Returns

  `{:ok, nodes}` where nodes is a list of node data sorted by relevance score.

  ## Examples

      iex> {:ok, nodes} = Grapple.Search.fuzzy_search("machne lernin", distance: 2)
      {:ok, [...]}

      iex> {:ok, nodes} = Grapple.Search.fuzzy_search("graff", distance: 1, fields: [:title])
      {:ok, [...]}
  """
  def fuzzy_search(query, opts \\ []) when is_binary(query) do
    case InvertedIndex.fuzzy_search(query, opts) do
      {:ok, scores} ->
        nodes = fetch_and_sort_nodes(scores, opts)
        {:ok, nodes}

      error ->
        error
    end
  end

  @doc """
  Searches for nodes containing an exact phrase.

  ## Parameters

    * `phrase` - The exact phrase to search for
    * `opts` - Search options
      * `:fields` - List of fields to search in
      * `:limit` - Maximum number of results to return (default: 100)
      * `:min_score` - Minimum relevance score (default: 0)

  ## Returns

  `{:ok, nodes}` where nodes is a list of node data sorted by relevance score.

  ## Examples

      iex> {:ok, nodes} = Grapple.Search.phrase_search("machine learning")
      {:ok, [...]}

      iex> {:ok, nodes} = Grapple.Search.phrase_search("exact match", fields: [:description])
      {:ok, [...]}
  """
  def phrase_search(phrase, opts \\ []) when is_binary(phrase) do
    case InvertedIndex.phrase_search(phrase, opts) do
      {:ok, scores} ->
        nodes = fetch_and_sort_nodes(scores, opts)
        {:ok, nodes}

      error ->
        error
    end
  end

  @doc """
  Indexes a node for full-text search.

  This function has two forms:

  ## Form 1: Convenience (auto-fetch properties)

  When called with just a node_id, or with node_id and a list of fields,
  the function automatically fetches the node's properties from the store.

      # Index all string fields
      Grapple.Search.index_node(node_id)

      # Index only specific fields
      Grapple.Search.index_node(node_id, [:title, :description])

  ## Form 2: Explicit properties

  When called with node_id, properties map, and optional fields,
  uses the provided properties directly.

      # Index with explicit properties
      Grapple.Search.index_node(node_id, %{title: "Hello"})

      # Index specific fields from explicit properties
      Grapple.Search.index_node(node_id, %{title: "Hello", secret: "Hidden"}, [:title])

  ## Parameters

    * `node_id` - The ID of the node to index
    * `properties_or_fields` - Either a map of properties, or a list of fields to index
    * `fields` - Optional list of specific fields to index (only when second arg is a map)

  ## Examples

      # Create a node and index it (convenience form)
      iex> {:ok, node_id} = Grapple.create_node(%{title: "Graph Databases", description: "A guide"})
      iex> Grapple.Search.index_node(node_id)
      :ok

      # Index only specific fields (convenience form)
      iex> {:ok, node_id} = Grapple.create_node(%{title: "Hello", description: "World"})
      iex> Grapple.Search.index_node(node_id, [:title])
      :ok

      # Index with explicit properties
      iex> Grapple.Search.index_node(1, %{title: "Hello", description: "World"})
      :ok

      # Index specific fields from explicit properties
      iex> Grapple.Search.index_node(1, %{title: "Hello", count: 42}, [:title])
      :ok
  """
  # Form 1a: Just node_id - fetch properties and index all fields
  def index_node(node_id) do
    case EtsGraphStore.get_node(node_id) do
      {:ok, node} ->
        InvertedIndex.index_node(node_id, node.properties, nil)

      {:error, :not_found} ->
        {:error, :node_not_found}
    end
  end

  # Form 1b: node_id with list of fields - fetch properties and index specific fields
  def index_node(node_id, fields) when is_list(fields) do
    case EtsGraphStore.get_node(node_id) do
      {:ok, node} ->
        InvertedIndex.index_node(node_id, node.properties, fields)

      {:error, :not_found} ->
        {:error, :node_not_found}
    end
  end

  # Form 2a: node_id with properties map - index all fields from provided properties
  def index_node(node_id, properties) when is_map(properties) do
    InvertedIndex.index_node(node_id, properties, nil)
  end

  @doc """
  Indexes a node for full-text search with explicit properties and optional field filter.

  ## Parameters

    * `node_id` - The ID of the node to index
    * `properties` - Map of node properties
    * `fields` - Optional list of specific fields to index (default: all string fields)

  ## Examples

      iex> Grapple.Search.index_node(1, %{title: "Hello", description: "World"}, nil)
      :ok

      iex> Grapple.Search.index_node(1, %{title: "Hello", count: 42}, [:title])
      :ok
  """
  # Form 2b: node_id with properties map and fields list
  def index_node(node_id, properties, fields) when is_map(properties) do
    InvertedIndex.index_node(node_id, properties, fields)
  end

  @doc """
  Removes a node from the search index.

  This is typically called automatically when nodes are deleted,
  but can be called manually if needed.

  ## Parameters

    * `node_id` - The ID of the node to remove from the index

  ## Examples

      iex> Grapple.Search.remove_node(1)
      :ok
  """
  def remove_node(node_id) do
    InvertedIndex.remove_node(node_id)
  end

  @doc """
  Re-indexes all nodes in the graph.

  This scans all nodes and rebuilds the full-text search index.
  Useful after changing analyzer options or for maintenance.

  ## Examples

      iex> Grapple.Search.reindex_all()
      {:ok, %{indexed: 150, errors: 0}}
  """
  def reindex_all(opts \\ []) do
    {:ok, nodes} = EtsGraphStore.list_nodes()

    results =
      Enum.reduce(nodes, %{indexed: 0, errors: 0}, fn node, acc ->
        case index_node(node.id, node.properties, opts[:fields]) do
          :ok ->
            %{acc | indexed: acc.indexed + 1}

          _error ->
            %{acc | errors: acc.errors + 1}
        end
      end)

    {:ok, results}
  end

  @doc """
  Gets statistics about the search index.

  Returns information about index size, memory usage, and indexed documents.

  ## Examples

      iex> Grapple.Search.get_stats()
      %{
        total_tokens: 1543,
        indexed_documents: 150,
        memory_usage: %{index: 42000, documents: 18000}
      }
  """
  def get_stats do
    InvertedIndex.get_stats()
  end

  # Private functions

  defp fetch_and_sort_nodes(scores, opts) do
    min_score = Keyword.get(opts, :min_score, 0)
    limit = Keyword.get(opts, :limit, 100)

    scores
    |> Enum.filter(fn {_node_id, score} -> score >= min_score end)
    |> Enum.sort_by(fn {_node_id, score} -> score end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {node_id, score} ->
      case EtsGraphStore.get_node(node_id) do
        {:ok, node} ->
          Map.put(node, :search_score, score)

        _error ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
