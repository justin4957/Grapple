defmodule Grapple.Search do
  @moduledoc """
  Full-text search capabilities for Grapple graph database.

  Provides powerful text search functionality including:
  - Basic text search with AND/OR operators
  - Fuzzy search with edit distance tolerance
  - Phrase search for exact matches
  - Multi-field search support
  - Relevance scoring

  ## Examples

      # Basic text search
      {:ok, nodes} = Grapple.Search.search("machine learning")

      # Search specific fields
      {:ok, nodes} = Grapple.Search.search("graph database", fields: [:title, :description])

      # Fuzzy search with typo tolerance
      {:ok, nodes} = Grapple.Search.fuzzy_search("machne lernin", distance: 2)

      # Phrase search for exact matches
      {:ok, nodes} = Grapple.Search.phrase_search("exact phrase")

      # Search with AND operator
      {:ok, nodes} = Grapple.Search.search("machine learning", operator: :and)
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

  This is typically called automatically when nodes are created or updated,
  but can be called manually to re-index specific nodes.

  ## Parameters

    * `node_id` - The ID of the node to index
    * `properties` - Map of node properties
    * `fields` - Optional list of specific fields to index (default: all string fields)

  ## Examples

      iex> Grapple.Search.index_node(1, %{title: "Hello", description: "World"})
      :ok

      iex> Grapple.Search.index_node(1, %{title: "Hello", count: 42}, [:title])
      :ok
  """
  def index_node(node_id, properties, fields \\ nil) do
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
