defmodule Grapple.ErrorTest do
  use ExUnit.Case, async: true
  alias Grapple.Error

  describe "error creation" do
    test "creates validation error" do
      error = Error.validation_error("Invalid input", field: :name)
      assert {:error, :validation_error, "Invalid input", [field: :name]} = error
    end

    test "creates node not found error" do
      error = Error.node_not_found(123)
      assert {:error, :node_not_found, message, opts} = error
      assert message =~ "Node 123"
      assert Keyword.get(opts, :node_id) == 123
    end

    test "creates edge not found error" do
      error = Error.edge_not_found(456)
      assert {:error, :edge_not_found, message, opts} = error
      assert message =~ "Edge 456"
      assert Keyword.get(opts, :edge_id) == 456
    end

    test "creates invalid properties error" do
      error = Error.invalid_properties("Bad property", invalid_fields: [:age])
      assert {:error, :invalid_properties, "Bad property", opts} = error
      assert Keyword.has_key?(opts, :invalid_fields)
    end

    test "creates query syntax error" do
      error = Error.invalid_query_syntax("Syntax error", query: "BAD QUERY")
      assert {:error, :invalid_query_syntax, "Syntax error", opts} = error
      assert Keyword.has_key?(opts, :query)
    end

    test "creates connection failed error" do
      error = Error.connection_failed(:node1, :timeout)
      assert {:error, :connection_failed, message, opts} = error
      assert message =~ "node1"
      assert Keyword.get(opts, :target_node) == :node1
      assert Keyword.get(opts, :reason) == :timeout
    end

    test "creates timeout error" do
      error = Error.timeout_error("query_execution", 5000)
      assert {:error, :timeout, message, opts} = error
      assert message =~ "query_execution"
      assert message =~ "5000ms"
      assert Keyword.get(opts, :operation) == "query_execution"
    end
  end

  describe "format_error/1" do
    test "formats simple error atom" do
      message = Error.format_error({:error, :not_found})
      assert message == "Error: Not found"
    end

    test "formats structured error" do
      error = Error.validation_error("Invalid input")
      message = Error.format_error(error)
      assert message =~ "Validation error"
      assert message =~ "Invalid input"
    end

    test "formats simple error string" do
      message = Error.format_error({:error, "Something went wrong"})
      assert message == "Error: Something went wrong"
    end

    test "handles unknown error format" do
      message = Error.format_error({:unknown, :format})
      assert message =~ "Unknown error"
    end
  end

  describe "recovery_suggestions/1" do
    test "provides suggestions for node not found" do
      error = Error.node_not_found(123)
      suggestions = Error.recovery_suggestions(error)
      assert is_list(suggestions)
      assert length(suggestions) > 0
      assert Enum.any?(suggestions, &String.contains?(&1, "SHOW GRAPH"))
    end

    test "provides suggestions for connection failed" do
      error = Error.connection_failed(:node1, nil)
      suggestions = Error.recovery_suggestions(error)
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &String.contains?(&1, "reachable"))
    end

    test "provides suggestions for query syntax error" do
      error = Error.invalid_query_syntax("Bad syntax")
      suggestions = Error.recovery_suggestions(error)
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &String.contains?(&1, "MATCH"))
    end

    test "provides generic suggestions for unknown errors" do
      error = {:error, :unknown_error, "Unknown", []}
      suggestions = Error.recovery_suggestions(error)
      assert is_list(suggestions)
      assert Enum.any?(suggestions, &String.contains?(&1, "help"))
    end
  end

  describe "retryable?/1" do
    test "timeout errors are retryable" do
      error = Error.timeout_error("operation", 1000)
      assert Error.retryable?(error)
    end

    test "network errors are retryable" do
      error = {:error, :network_error, "Network failure", []}
      assert Error.retryable?(error)
    end

    test "cluster unavailable errors are retryable" do
      error = {:error, :cluster_unavailable, "Cluster down", []}
      assert Error.retryable?(error)
    end

    test "connection failed errors are retryable" do
      error = Error.connection_failed(:node1, nil)
      assert Error.retryable?(error)
    end

    test "validation errors are not retryable" do
      error = Error.validation_error("Bad input")
      refute Error.retryable?(error)
    end

    test "not found errors are not retryable" do
      error = Error.node_not_found(123)
      refute Error.retryable?(error)
    end

    test "query syntax errors are not retryable" do
      error = Error.invalid_query_syntax("Bad query")
      refute Error.retryable?(error)
    end
  end

  describe "wrap_result/1" do
    test "passes through success tuples" do
      assert {:ok, 42} = Error.wrap_result({:ok, 42})
    end

    test "wraps simple error atoms" do
      {:error, reason, _message, _opts} = Error.wrap_result({:error, :not_found})
      assert reason == :not_found
    end

    test "passes through structured errors" do
      error = Error.validation_error("Bad input")
      assert ^error = Error.wrap_result(error)
    end

    test "wraps unexpected results" do
      {:error, :unknown_error, message, _opts} = Error.wrap_result(:unexpected)
      assert message =~ "Unexpected result"
    end
  end
end
