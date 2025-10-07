defmodule Grapple.Validation do
  @moduledoc """
  Input validation and sanitization for Grapple Graph Database operations.

  Provides comprehensive validation for nodes, edges, properties, and queries.
  """

  alias Grapple.Error

  @max_property_key_length 255
  @max_property_value_length 10_000
  @max_label_length 255
  @max_properties_per_node 1000
  @valid_directions [:in, :out, :both]

  @doc """
  Validates node properties before creation or update.

  Returns `{:ok, validated_properties}` or `{:error, reason}`.

  ## Rules
  - Properties must be a map
  - Keys must be atoms or strings (converted to atoms)
  - Keys cannot be longer than #{@max_property_key_length} characters
  - Values cannot be longer than #{@max_property_value_length} characters (for strings)
  - Maximum #{@max_properties_per_node} properties per node
  - No nil values allowed
  - Keys cannot start with underscore (reserved for internal use)
  """
  def validate_node_properties(properties) when is_map(properties) do
    cond do
      map_size(properties) > @max_properties_per_node ->
        Error.invalid_properties(
          "Too many properties (max: #{@max_properties_per_node})",
          count: map_size(properties)
        )

      true ->
        properties
        |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
          case validate_property_pair(key, value) do
            {:ok, validated_key, validated_value} ->
              {:cont, {:ok, Map.put(acc, validated_key, validated_value)}}

            {:error, _reason, _message, _opts} = error ->
              {:halt, error}
          end
        end)
    end
  end

  def validate_node_properties(nil), do: {:ok, %{}}
  def validate_node_properties(_), do: Error.invalid_properties("Properties must be a map")

  @doc """
  Validates a single property key-value pair.
  """
  def validate_property_pair(key, value) do
    with {:ok, validated_key} <- validate_property_key(key),
         {:ok, validated_value} <- validate_property_value(value) do
      {:ok, validated_key, validated_value}
    end
  end

  @doc """
  Validates a property key.
  """
  def validate_property_key(key) when is_atom(key) do
    key_string = Atom.to_string(key)
    validate_property_key_string(key_string, key)
  end

  def validate_property_key(key) when is_binary(key) do
    key_atom = String.to_atom(key)
    validate_property_key_string(key, key_atom)
  end

  def validate_property_key(_) do
    Error.invalid_properties("Property keys must be atoms or strings")
  end

  defp validate_property_key_string(key_string, return_key) do
    cond do
      String.length(key_string) == 0 ->
        Error.invalid_properties("Property key cannot be empty")

      String.length(key_string) > @max_property_key_length ->
        Error.invalid_properties(
          "Property key too long (max: #{@max_property_key_length} chars)",
          key: key_string
        )

      String.starts_with?(key_string, "_") ->
        Error.invalid_properties(
          "Property keys cannot start with underscore (reserved)",
          key: key_string
        )

      not valid_key_format?(key_string) ->
        Error.invalid_properties(
          "Property key contains invalid characters (use alphanumeric and underscores only)",
          key: key_string
        )

      true ->
        {:ok, return_key}
    end
  end

  @doc """
  Validates a property value.
  """
  def validate_property_value(nil) do
    Error.invalid_properties("Property values cannot be nil")
  end

  def validate_property_value(value) when is_binary(value) do
    if String.length(value) > @max_property_value_length do
      Error.invalid_properties(
        "Property value too long (max: #{@max_property_value_length} chars)",
        length: String.length(value)
      )
    else
      {:ok, value}
    end
  end

  def validate_property_value(value)
      when is_integer(value) or is_float(value) or is_boolean(value) or is_atom(value) do
    {:ok, value}
  end

  def validate_property_value(value) when is_list(value) do
    # Validate list elements
    Enum.reduce_while(value, {:ok, []}, fn item, {:ok, acc} ->
      case validate_property_value(item) do
        {:ok, validated_item} -> {:cont, {:ok, [validated_item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, validated_list} -> {:ok, Enum.reverse(validated_list)}
      error -> error
    end
  end

  def validate_property_value(_value) do
    Error.invalid_properties(
      "Unsupported property value type (use: string, number, boolean, atom, or list)"
    )
  end

  @doc """
  Validates an edge label.

  ## Rules
  - Must be a string or atom
  - Cannot be empty
  - Cannot be longer than #{@max_label_length} characters
  - Must contain only alphanumeric characters, underscores, and hyphens
  """
  def validate_edge_label(label) when is_atom(label) do
    validate_edge_label(Atom.to_string(label))
  end

  def validate_edge_label(label) when is_binary(label) do
    cond do
      String.length(label) == 0 ->
        {:error, :invalid_label, "Edge label cannot be empty", []}

      String.length(label) > @max_label_length ->
        {:error, :invalid_label, "Edge label too long (max: #{@max_label_length} chars)",
         length: String.length(label)}

      not valid_label_format?(label) ->
        {:error, :invalid_label,
         "Edge label contains invalid characters (use alphanumeric, underscores, and hyphens)",
         label: label}

      true ->
        {:ok, label}
    end
  end

  def validate_edge_label(_) do
    {:error, :invalid_label, "Edge label must be a string or atom", []}
  end

  @doc """
  Validates a node or edge ID.
  """
  def validate_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  def validate_id(id) when is_integer(id) do
    Error.validation_error("ID must be a positive integer", id: id)
  end

  def validate_id(_) do
    Error.validation_error("ID must be an integer")
  end

  @doc """
  Validates a traversal direction.
  """
  def validate_direction(direction) when direction in @valid_directions do
    {:ok, direction}
  end

  def validate_direction(direction) do
    Error.validation_error(
      "Invalid direction (must be one of: #{inspect(@valid_directions)})",
      direction: direction
    )
  end

  @doc """
  Validates a depth parameter for traversal operations.
  """
  def validate_depth(depth) when is_integer(depth) and depth >= 0 and depth <= 100 do
    {:ok, depth}
  end

  def validate_depth(depth) when is_integer(depth) do
    Error.validation_error("Depth must be between 0 and 100", depth: depth)
  end

  def validate_depth(_) do
    Error.validation_error("Depth must be an integer")
  end

  @doc """
  Validates query syntax before parsing.
  """
  def validate_query_syntax(query) when is_binary(query) do
    cond do
      String.trim(query) == "" ->
        Error.invalid_query_syntax("Query cannot be empty")

      String.length(query) > 10_000 ->
        Error.invalid_query_syntax("Query too long (max: 10000 chars)")

      not valid_query_commands?(query) ->
        Error.invalid_query_syntax(
          "Query must start with a valid command (MATCH, CREATE, FIND, etc.)",
          query: query
        )

      true ->
        {:ok, query}
    end
  end

  def validate_query_syntax(_) do
    Error.invalid_query_syntax("Query must be a string")
  end

  # Private helper functions
  defp valid_key_format?(key) do
    Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_]*$/, key)
  end

  defp valid_label_format?(label) do
    Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_\-]*$/, label)
  end

  defp valid_query_commands?(query) do
    query_upper = String.upcase(query)

    Enum.any?(
      [
        "MATCH",
        "CREATE",
        "FIND",
        "TRAVERSE",
        "PATH",
        "SHOW",
        "VISUALIZE",
        "DELETE",
        "UPDATE"
      ],
      &String.starts_with?(query_upper, &1)
    )
  end
end
