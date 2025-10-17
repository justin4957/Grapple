defmodule Grapple.Search.InvertedIndex do
  @moduledoc """
  ETS-based inverted index for full-text search.
  Maps tokens to lists of node IDs and field names where they appear.
  """

  use GenServer
  alias Grapple.Search.TextAnalyzer

  defstruct [
    :index_table,
    :document_table,
    :analyzer_options
  ]

  # Table names
  @index_table :grapple_search_index
  @document_table :grapple_search_documents

  @doc """
  Starts the inverted index GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initializes the inverted index tables.
  """
  def init(opts) do
    # Create index table: {token, [{node_id, field, position}]}
    index_table =
      create_table(@index_table, [:bag, :named_table, :public, {:read_concurrency, true}])

    # Create document table: {node_id, %{field => [tokens]}}
    document_table =
      create_table(@document_table, [:set, :named_table, :public, {:read_concurrency, true}])

    analyzer_options = Keyword.get(opts, :analyzer_options, [])

    state = %__MODULE__{
      index_table: index_table,
      document_table: document_table,
      analyzer_options: analyzer_options
    }

    {:ok, state}
  end

  # Public API

  @doc """
  Indexes a node's text properties.

  ## Parameters

    * `node_id` - The node ID to index
    * `properties` - A map of field names to text values
    * `fields` - List of fields to index (if nil, indexes all string values)

  ## Examples

      iex> Grapple.Search.InvertedIndex.index_node(1, %{title: "Hello World", description: "A greeting"})
      :ok
  """
  def index_node(node_id, properties, fields \\ nil) do
    GenServer.call(__MODULE__, {:index_node, node_id, properties, fields})
  end

  @doc """
  Removes a node from the index.
  """
  def remove_node(node_id) do
    GenServer.call(__MODULE__, {:remove_node, node_id})
  end

  @doc """
  Searches the index for tokens matching a query.

  ## Parameters

    * `query` - The search query string
    * `opts` - Search options
      * `:fields` - List of fields to search (default: all fields)
      * `:operator` - Boolean operator `:and` or `:or` (default: `:or`)
      * `:analyzer_options` - Options to pass to the text analyzer

  ## Returns

  A map of node IDs to their relevance scores.
  """
  def search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, query, opts})
  end

  @doc """
  Performs fuzzy search with edit distance tolerance.

  ## Parameters

    * `query` - The search query string
    * `opts` - Search options
      * `:distance` - Maximum Levenshtein distance (default: 2)
      * `:fields` - List of fields to search
      * `:operator` - Boolean operator `:and` or `:or` (default: `:or`)

  ## Returns

  A map of node IDs to their relevance scores.
  """
  def fuzzy_search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:fuzzy_search, query, opts})
  end

  @doc """
  Searches for an exact phrase in the index.

  ## Parameters

    * `phrase` - The exact phrase to search for
    * `opts` - Search options
      * `:fields` - List of fields to search

  ## Returns

  A map of node IDs to their relevance scores.
  """
  def phrase_search(phrase, opts \\ []) do
    GenServer.call(__MODULE__, {:phrase_search, phrase, opts})
  end

  @doc """
  Gets statistics about the index.
  """
  def get_stats do
    %{
      total_tokens: :ets.info(@index_table, :size),
      indexed_documents: :ets.info(@document_table, :size),
      memory_usage: %{
        index: :ets.info(@index_table, :memory),
        documents: :ets.info(@document_table, :memory)
      }
    }
  end

  # GenServer callbacks

  def handle_call({:index_node, node_id, properties, fields}, _from, state) do
    # Remove existing index entries for this node
    remove_node_from_index(node_id, state)

    # Determine which fields to index
    fields_to_index = determine_fields_to_index(properties, fields)

    # Index each field
    field_tokens =
      Enum.reduce(fields_to_index, %{}, fn field, acc ->
        case Map.get(properties, field) do
          value when is_binary(value) ->
            tokens = TextAnalyzer.analyze(value, state.analyzer_options)
            index_field_tokens(node_id, field, tokens, state)
            Map.put(acc, field, tokens)

          _ ->
            acc
        end
      end)

    # Store document tokens for phrase search
    :ets.insert(state.document_table, {node_id, field_tokens})

    {:reply, :ok, state}
  end

  def handle_call({:remove_node, node_id}, _from, state) do
    result = remove_node_from_index(node_id, state)
    {:reply, result, state}
  end

  def handle_call({:search, query, opts}, _from, state) do
    analyzer_options = Keyword.get(opts, :analyzer_options, state.analyzer_options)
    query_tokens = TextAnalyzer.analyze(query, analyzer_options)
    operator = Keyword.get(opts, :operator, :or)
    fields_filter = Keyword.get(opts, :fields)

    scores = search_tokens(query_tokens, operator, fields_filter, state)

    {:reply, {:ok, scores}, state}
  end

  def handle_call({:fuzzy_search, query, opts}, _from, state) do
    max_distance = Keyword.get(opts, :distance, 2)
    analyzer_options = Keyword.get(opts, :analyzer_options, state.analyzer_options)
    query_tokens = TextAnalyzer.analyze(query, analyzer_options)
    operator = Keyword.get(opts, :operator, :or)
    fields_filter = Keyword.get(opts, :fields)

    # Get all tokens from the index
    all_tokens =
      :ets.tab2list(state.index_table)
      |> Enum.map(fn {token, _} -> token end)
      |> Enum.uniq()

    # Find fuzzy matches for each query token
    fuzzy_matches =
      Enum.flat_map(query_tokens, fn query_token ->
        Enum.filter(all_tokens, fn index_token ->
          TextAnalyzer.levenshtein_distance(query_token, index_token) <= max_distance
        end)
      end)
      |> Enum.uniq()

    scores = search_tokens(fuzzy_matches, operator, fields_filter, state)

    {:reply, {:ok, scores}, state}
  end

  def handle_call({:phrase_search, phrase, opts}, _from, state) do
    analyzer_options = Keyword.get(opts, :analyzer_options, state.analyzer_options)
    phrase_tokens = TextAnalyzer.analyze(phrase, analyzer_options)
    fields_filter = Keyword.get(opts, :fields)

    scores = phrase_search_impl(phrase_tokens, fields_filter, state)

    {:reply, {:ok, scores}, state}
  end

  # Private functions

  defp create_table(name, opts) do
    case :ets.info(name) do
      :undefined ->
        :ets.new(name, opts)

      _ ->
        :ets.delete(name)
        :ets.new(name, opts)
    end
  end

  defp determine_fields_to_index(properties, nil) do
    # Index all string fields
    properties
    |> Enum.filter(fn {_key, value} -> is_binary(value) end)
    |> Enum.map(fn {key, _value} -> key end)
  end

  defp determine_fields_to_index(_properties, fields) when is_list(fields) do
    fields
  end

  defp index_field_tokens(node_id, field, tokens, state) do
    tokens
    |> Enum.with_index()
    |> Enum.each(fn {token, position} ->
      :ets.insert(state.index_table, {token, {node_id, field, position}})
    end)
  end

  defp remove_node_from_index(node_id, state) do
    # Get the document's indexed tokens
    case :ets.lookup(state.document_table, node_id) do
      [{^node_id, field_tokens}] ->
        # Remove all index entries for this node
        Enum.each(field_tokens, fn {field, tokens} ->
          Enum.each(tokens, fn token ->
            # Get all entries for this token
            entries = :ets.lookup(state.index_table, token)

            # Remove entries matching this node_id
            Enum.each(entries, fn {^token, {nid, fld, pos}} ->
              if nid == node_id and fld == field do
                :ets.delete_object(state.index_table, {token, {nid, fld, pos}})
              end
            end)
          end)
        end)

        # Remove from document table
        :ets.delete(state.document_table, node_id)
        :ok

      [] ->
        :ok
    end
  end

  defp search_tokens(tokens, operator, fields_filter, state) do
    # Get matching node IDs for each token
    token_matches =
      Enum.map(tokens, fn token ->
        entries = :ets.lookup(state.index_table, token)

        entries
        |> Enum.filter(fn {_token, {_node_id, field, _position}} ->
          fields_filter == nil or field in fields_filter
        end)
        |> Enum.map(fn {_token, {node_id, _field, _position}} -> node_id end)
        |> MapSet.new()
      end)

    # Apply boolean operator
    matching_nodes =
      case operator do
        :and ->
          if token_matches == [] do
            MapSet.new()
          else
            Enum.reduce(token_matches, fn set, acc -> MapSet.intersection(set, acc) end)
          end

        :or ->
          Enum.reduce(token_matches, MapSet.new(), fn set, acc -> MapSet.union(set, acc) end)
      end

    # Calculate relevance scores (simple TF-based scoring)
    scores =
      Enum.reduce(matching_nodes, %{}, fn node_id, acc ->
        # Count how many query tokens appear in this document
        score =
          Enum.reduce(tokens, 0, fn token, count ->
            entries = :ets.lookup(state.index_table, token)

            node_count =
              entries
              |> Enum.filter(fn {_token, {nid, field, _position}} ->
                nid == node_id and (fields_filter == nil or field in fields_filter)
              end)
              |> length()

            count + node_count
          end)

        Map.put(acc, node_id, score)
      end)

    scores
  end

  defp phrase_search_impl(phrase_tokens, fields_filter, state) do
    if phrase_tokens == [] do
      %{}
    else
      # Get candidates that contain the first token
      first_token = hd(phrase_tokens)
      first_token_entries = :ets.lookup(state.index_table, first_token)

      # Group by node_id and field
      candidates =
        first_token_entries
        |> Enum.filter(fn {_token, {_node_id, field, _position}} ->
          fields_filter == nil or field in fields_filter
        end)
        |> Enum.group_by(fn {_token, {node_id, field, _position}} -> {node_id, field} end)

      # Check each candidate for the complete phrase
      Enum.reduce(candidates, %{}, fn {{node_id, field}, entries}, acc ->
        # Get starting positions for the first token
        starting_positions =
          entries
          |> Enum.map(fn {_token, {_node_id, _field, position}} -> position end)

        # Check if the phrase appears starting at any of these positions
        phrase_found =
          Enum.any?(starting_positions, fn start_pos ->
            check_phrase_at_position(phrase_tokens, node_id, field, start_pos, state)
          end)

        if phrase_found do
          Map.put(acc, node_id, length(phrase_tokens) * 2)
        else
          acc
        end
      end)
    end
  end

  defp check_phrase_at_position(phrase_tokens, node_id, field, start_pos, state) do
    phrase_tokens
    |> Enum.with_index()
    |> Enum.all?(fn {token, offset} ->
      expected_position = start_pos + offset
      entries = :ets.lookup(state.index_table, token)

      Enum.any?(entries, fn {_token, {nid, fld, pos}} ->
        nid == node_id and fld == field and pos == expected_position
      end)
    end)
  end

  def terminate(_reason, state) do
    :ets.delete(state.index_table)
    :ets.delete(state.document_table)
    :ok
  end
end
