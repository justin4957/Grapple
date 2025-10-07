defmodule Grapple.Error do
  @moduledoc """
  Comprehensive error types and handling for Grapple Graph Database.

  Provides structured error definitions with detailed messages and recovery suggestions.
  """

  @type error_reason ::
          :validation_error
          | :node_not_found
          | :edge_not_found
          | :invalid_node_id
          | :invalid_edge_id
          | :invalid_properties
          | :invalid_label
          | :invalid_query_syntax
          | :invalid_pattern
          | :unsupported_query
          | :connection_failed
          | :cluster_unavailable
          | :timeout
          | :invalid_depth
          | :path_not_found
          | :network_error
          | :insufficient_resources
          | :duplicate_entry
          | :constraint_violation

  @type t :: {:error, error_reason, String.t(), keyword()}

  @doc """
  Creates a validation error with helpful context.
  """
  def validation_error(message, opts \\ []) do
    {:error, :validation_error, message, opts}
  end

  @doc """
  Creates a node not found error.
  """
  def node_not_found(node_id) do
    {:error, :node_not_found, "Node #{node_id} does not exist in the graph", node_id: node_id}
  end

  @doc """
  Creates an edge not found error.
  """
  def edge_not_found(edge_id) do
    {:error, :edge_not_found, "Edge #{edge_id} does not exist in the graph", edge_id: edge_id}
  end

  @doc """
  Creates an invalid properties error with details about what's wrong.
  """
  def invalid_properties(message, invalid_fields \\ []) do
    {:error, :invalid_properties, message, invalid_fields: invalid_fields}
  end

  @doc """
  Creates a query syntax error with helpful suggestions.
  """
  def invalid_query_syntax(message, query \\ nil) do
    {:error, :invalid_query_syntax, message, query: query}
  end

  @doc """
  Creates a cluster connection error.
  """
  def connection_failed(target_node, reason \\ nil) do
    message = "Failed to connect to node #{target_node}"
    message = if reason, do: "#{message}: #{inspect(reason)}", else: message
    {:error, :connection_failed, message, target_node: target_node, reason: reason}
  end

  @doc """
  Creates a timeout error with context.
  """
  def timeout_error(operation, duration_ms) do
    {:error, :timeout, "Operation #{operation} timed out after #{duration_ms}ms",
     operation: operation, duration: duration_ms}
  end

  @doc """
  Formats an error tuple into a user-friendly message.
  """
  def format_error({:error, reason}) when is_atom(reason) do
    "Error: #{humanize_atom(reason)}"
  end

  def format_error({:error, reason, message, _opts}) when is_atom(reason) do
    "#{humanize_atom(reason)}: #{message}"
  end

  def format_error({:error, reason}) when is_binary(reason) do
    "Error: #{reason}"
  end

  def format_error(error) do
    "Unknown error: #{inspect(error)}"
  end

  @doc """
  Provides recovery suggestions based on error type.
  """
  def recovery_suggestions({:error, :node_not_found, _message, opts}) do
    node_id = Keyword.get(opts, :node_id)

    [
      "Verify the node ID #{node_id} exists using: SHOW GRAPH",
      "List all nodes to find the correct ID: FIND NODES <property> <value>",
      "Create a new node if needed: CREATE NODE {properties}"
    ]
  end

  def recovery_suggestions({:error, :connection_failed, _message, opts}) do
    target = Keyword.get(opts, :target_node)

    [
      "Check if node #{target} is running and reachable",
      "Verify network connectivity and firewall rules",
      "Ensure both nodes have the same Erlang cookie configured",
      "Check the node name format: node@hostname"
    ]
  end

  def recovery_suggestions({:error, :invalid_query_syntax, _message, _opts}) do
    [
      "Check query syntax with: help",
      "Common patterns:",
      "  MATCH (n) - Match all nodes",
      "  MATCH (n {prop: \"value\"}) - Match nodes with properties",
      "  CREATE NODE {prop: \"value\"} - Create a node"
    ]
  end

  def recovery_suggestions({:error, :validation_error, _message, _opts}) do
    [
      "Ensure all required fields are provided",
      "Check data types match expected formats",
      "Review property names and values for special characters"
    ]
  end

  def recovery_suggestions(_error) do
    [
      "Type 'help' for available commands",
      "Check the documentation for usage examples"
    ]
  end

  @doc """
  Determines if an error is retryable (for implementing retry logic).
  """
  def retryable?({:error, :timeout, _message, _opts}), do: true
  def retryable?({:error, :network_error, _message, _opts}), do: true
  def retryable?({:error, :cluster_unavailable, _message, _opts}), do: true
  def retryable?({:error, :connection_failed, _message, _opts}), do: true
  def retryable?(_error), do: false

  @doc """
  Wraps an operation result into a standardized error format.
  """
  def wrap_result({:ok, _value} = result), do: result

  def wrap_result({:error, reason}) when is_atom(reason) do
    {:error, reason, humanize_atom(reason), []}
  end

  def wrap_result({:error, _reason, _message, _opts} = error), do: error

  def wrap_result(other) do
    {:error, :unknown_error, "Unexpected result: #{inspect(other)}", []}
  end

  # Private helper functions
  defp humanize_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
