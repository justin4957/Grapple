defmodule Grapple.Query.Language do
  @moduledoc """
  Query language specification and parser for Grapple Graph Database.

  Supports basic graph query operations:
  - MATCH: Pattern matching for nodes and relationships
  - CREATE: Creating nodes and relationships
  - RETURN: Selecting data to return
  - WHERE: Filtering conditions
  """

  alias Grapple.{Validation, Error}

  defstruct [:type, :clauses, :return, :where]

  def parse(query_string) do
    with {:ok, validated_query} <- Validation.validate_query_syntax(query_string) do
      validated_query
      |> String.trim()
      |> tokenize()
      |> parse_tokens()
    end
  end

  defp tokenize(query) do
    # Basic tokenizer - splits on whitespace and preserves patterns
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.upcase/1)
  end

  defp parse_tokens(["MATCH" | rest]) do
    {pattern, remaining} = extract_pattern(rest)
    {return_clause, where_clause} = parse_remaining_clauses(remaining)
    
    {:ok, %__MODULE__{
      type: :match,
      clauses: [pattern: pattern],
      return: return_clause,
      where: where_clause
    }}
  end

  defp parse_tokens(["CREATE" | rest]) do
    {pattern, _remaining} = extract_pattern(rest)
    
    {:ok, %__MODULE__{
      type: :create,
      clauses: [pattern: pattern]
    }}
  end

  defp parse_tokens([]) do
    Error.invalid_query_syntax("Empty query provided")
  end

  defp parse_tokens(tokens) do
    Error.invalid_query_syntax(
      "Unsupported query command: #{List.first(tokens)}",
      query: Enum.join(tokens, " ")
    )
  end

  defp extract_pattern(tokens) do
    # Extract node/relationship patterns like (n)-[r]->(m)
    pattern_string = Enum.join(tokens, " ")
    
    cond do
      String.contains?(pattern_string, ")->") ->
        parse_relationship_pattern(pattern_string)
      
      String.contains?(pattern_string, "(") ->
        parse_node_pattern(pattern_string)
      
      true ->
        {%{type: :simple, value: pattern_string}, []}
    end
  end

  defp parse_node_pattern(pattern) do
    # Parse (n {prop: value}) patterns
    case Regex.run(~r/\(([^)]*)\)/, pattern) do
      [_full, node_spec] ->
        {node_name, properties} = parse_node_spec(node_spec)
        {%{type: :node, name: node_name, properties: properties}, []}
      
      nil ->
        {%{type: :invalid, value: pattern}, []}
    end
  end

  defp parse_relationship_pattern(pattern) do
    # Parse (n)-[r:TYPE]->(m) patterns
    case Regex.run(~r/\(([^)]*)\)-\[([^\]]*)\]->\(([^)]*)\)/, pattern) do
      [_full, from_node, relationship, to_node] ->
        from_spec = parse_node_spec(from_node)
        rel_spec = parse_relationship_spec(relationship)
        to_spec = parse_node_spec(to_node)
        
        {%{
          type: :relationship,
          from: from_spec,
          relationship: rel_spec,
          to: to_spec
        }, []}
      
      nil ->
        {%{type: :invalid, value: pattern}, []}
    end
  end

  defp parse_node_spec(""), do: {nil, %{}}
  
  defp parse_node_spec(spec) do
    case String.split(spec, " ", parts: 2) do
      [name] when name != "" ->
        {name, %{}}
      
      [name, props_str] ->
        properties = parse_properties_string(props_str)
        {name, properties}
      
      [] ->
        {nil, %{}}
    end
  end

  defp parse_relationship_spec(""), do: %{label: nil}
  
  defp parse_relationship_spec(spec) do
    case String.split(spec, ":", parts: 2) do
      [var_name] when var_name != "" ->
        %{variable: var_name, label: nil}
      
      [var_name, label] ->
        %{variable: var_name, label: label}
      
      [] ->
        %{label: nil}
    end
  end

  defp parse_properties_string(props_str) do
    # Basic property parsing for {key: value, key2: value2}
    props_str
    |> String.trim()
    |> String.trim_leading("{")
    |> String.trim_trailing("}")
    |> String.split(",", trim: true)
    |> Enum.map(fn pair ->
      case String.split(pair, ":", parts: 2) do
        [key, value] ->
          clean_key = key |> String.trim() |> String.to_atom()
          clean_value = value |> String.trim() |> String.trim("\"")
          {clean_key, clean_value}
        
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp parse_remaining_clauses(tokens) do
    return_index = Enum.find_index(tokens, &(&1 == "RETURN"))
    where_index = Enum.find_index(tokens, &(&1 == "WHERE"))
    
    return_clause = if return_index do
      end_index = where_index || length(tokens)
      Enum.slice(tokens, (return_index + 1)..(end_index - 1))
    end
    
    where_clause = if where_index do
      Enum.slice(tokens, (where_index + 1)..-1)
    end
    
    {return_clause, where_clause}
  end

  def execute_query(%__MODULE__{type: :match} = query) do
    case query.clauses[:pattern] do
      %{type: :node} = pattern ->
        execute_node_match(pattern, query.where, query.return)
      
      %{type: :relationship} = pattern ->
        execute_relationship_match(pattern, query.where, query.return)
      
      _ ->
        {:error, :invalid_pattern}
    end
  end

  def execute_query(%__MODULE__{type: :create} = query) do
    case query.clauses[:pattern] do
      %{type: :node} = pattern ->
        execute_node_create(pattern)
      
      %{type: :relationship} = pattern ->
        execute_relationship_create(pattern)
      
      _ ->
        {:error, :invalid_pattern}
    end
  end

  defp execute_node_match(_pattern, _where_clause, _return_clause) do
    # Implementation for node matching
    {:ok, []}
  end

  defp execute_relationship_match(_pattern, _where_clause, _return_clause) do
    # Implementation for relationship matching
    {:ok, []}
  end

  defp execute_node_create(pattern) do
    # Implementation for node creation
    alias Grapple.Storage.EtsGraphStore
    EtsGraphStore.create_node(pattern.properties || %{})
  end

  defp execute_relationship_create(_pattern) do
    # Implementation for relationship creation
    {:ok, :created}
  end
end