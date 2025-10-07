defmodule Grapple.ValidationTest do
  use ExUnit.Case, async: true
  alias Grapple.Validation

  describe "validate_node_properties/1" do
    test "accepts valid properties" do
      properties = %{name: "Alice", age: 30, role: "Engineer"}
      assert {:ok, validated} = Validation.validate_node_properties(properties)
      assert validated == properties
    end

    test "accepts empty properties" do
      assert {:ok, %{}} = Validation.validate_node_properties(%{})
    end

    test "accepts nil as empty properties" do
      assert {:ok, %{}} = Validation.validate_node_properties(nil)
    end

    test "converts string keys to atoms" do
      properties = %{"name" => "Bob", "age" => 25}
      assert {:ok, validated} = Validation.validate_node_properties(properties)
      assert validated == %{name: "Bob", age: 25}
    end

    test "rejects properties that are not maps" do
      assert {:error, :invalid_properties, _message, _opts} =
               Validation.validate_node_properties("not a map")
    end

    test "rejects too many properties" do
      # Create a map with more than max properties
      properties = for i <- 1..1001, into: %{}, do: {String.to_atom("key#{i}"), "value#{i}"}

      assert {:error, :invalid_properties, message, _opts} =
               Validation.validate_node_properties(properties)

      assert message =~ "Too many properties"
    end

    test "rejects nil values" do
      properties = %{name: "Alice", age: nil}

      assert {:error, :invalid_properties, message, _opts} =
               Validation.validate_node_properties(properties)

      assert message =~ "cannot be nil"
    end

    test "rejects keys starting with underscore" do
      properties = %{_internal: "value"}

      assert {:error, :invalid_properties, message, _opts} =
               Validation.validate_node_properties(properties)

      assert message =~ "cannot start with underscore"
    end

    test "rejects keys with invalid characters" do
      properties = %{"key-with-dash": "value"}

      assert {:error, :invalid_properties, message, _opts} =
               Validation.validate_node_properties(properties)

      assert message =~ "invalid characters"
    end

    test "rejects values that are too long" do
      long_value = String.duplicate("a", 10_001)
      properties = %{name: long_value}

      assert {:error, :invalid_properties, message, _opts} =
               Validation.validate_node_properties(properties)

      assert message =~ "too long"
    end

    test "accepts various value types" do
      properties = %{
        string: "value",
        integer: 42,
        float: 3.14,
        boolean: true,
        atom: :status,
        list: [1, 2, 3]
      }

      assert {:ok, validated} = Validation.validate_node_properties(properties)
      assert validated == properties
    end
  end

  describe "validate_edge_label/1" do
    test "accepts valid label as string" do
      assert {:ok, "knows"} = Validation.validate_edge_label("knows")
    end

    test "accepts valid label as atom" do
      assert {:ok, "knows"} = Validation.validate_edge_label(:knows)
    end

    test "rejects empty label" do
      assert {:error, :invalid_label, message, _opts} = Validation.validate_edge_label("")
      assert message =~ "cannot be empty"
    end

    test "rejects label that is too long" do
      long_label = String.duplicate("a", 256)

      assert {:error, :invalid_label, message, _opts} = Validation.validate_edge_label(long_label)
      assert message =~ "too long"
    end

    test "accepts labels with hyphens and underscores" do
      assert {:ok, "friend-of"} = Validation.validate_edge_label("friend-of")
      assert {:ok, "reports_to"} = Validation.validate_edge_label("reports_to")
    end

    test "rejects labels with invalid characters" do
      assert {:error, :invalid_label, message, _opts} =
               Validation.validate_edge_label("label with spaces")

      assert message =~ "invalid characters"
    end

    test "rejects non-string/non-atom labels" do
      assert {:error, :invalid_label, _message, _opts} = Validation.validate_edge_label(123)
    end
  end

  describe "validate_id/1" do
    test "accepts positive integers" do
      assert {:ok, 1} = Validation.validate_id(1)
      assert {:ok, 100} = Validation.validate_id(100)
    end

    test "rejects zero" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_id(0)
    end

    test "rejects negative integers" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_id(-1)
    end

    test "rejects non-integers" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_id("1")
      assert {:error, :validation_error, _message, _opts} = Validation.validate_id(1.5)
    end
  end

  describe "validate_direction/1" do
    test "accepts valid directions" do
      assert {:ok, :in} = Validation.validate_direction(:in)
      assert {:ok, :out} = Validation.validate_direction(:out)
      assert {:ok, :both} = Validation.validate_direction(:both)
    end

    test "rejects invalid directions" do
      assert {:error, :validation_error, message, _opts} =
               Validation.validate_direction(:invalid)

      assert message =~ "Invalid direction"
    end
  end

  describe "validate_depth/1" do
    test "accepts valid depth values" do
      assert {:ok, 0} = Validation.validate_depth(0)
      assert {:ok, 10} = Validation.validate_depth(10)
      assert {:ok, 100} = Validation.validate_depth(100)
    end

    test "rejects negative depth" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_depth(-1)
    end

    test "rejects depth greater than 100" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_depth(101)
    end

    test "rejects non-integer depth" do
      assert {:error, :validation_error, _message, _opts} = Validation.validate_depth("10")
    end
  end

  describe "validate_query_syntax/1" do
    test "accepts valid query commands" do
      assert {:ok, "MATCH (n)"} = Validation.validate_query_syntax("MATCH (n)")

      assert {:ok, "CREATE NODE {name: \"Alice\"}"} =
               Validation.validate_query_syntax("CREATE NODE {name: \"Alice\"}")

      assert {:ok, "FIND NODES name Alice"} =
               Validation.validate_query_syntax("FIND NODES name Alice")
    end

    test "rejects empty query" do
      assert {:error, :invalid_query_syntax, message, _opts} =
               Validation.validate_query_syntax("")

      assert message =~ "cannot be empty"
    end

    test "rejects query that is too long" do
      long_query = "MATCH " <> String.duplicate("a", 10_000)

      assert {:error, :invalid_query_syntax, message, _opts} =
               Validation.validate_query_syntax(long_query)

      assert message =~ "too long"
    end

    test "rejects query without valid command" do
      assert {:error, :invalid_query_syntax, message, _opts} =
               Validation.validate_query_syntax("INVALID COMMAND")

      assert message =~ "must start with a valid command"
    end

    test "rejects non-string query" do
      assert {:error, :invalid_query_syntax, _message, _opts} =
               Validation.validate_query_syntax(123)
    end
  end
end
