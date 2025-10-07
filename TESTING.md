# Grapple Testing Guide

This document provides comprehensive information about testing Grapple, including test structure, coverage, and best practices.

## Test Structure

Grapple uses a comprehensive testing approach with multiple test types:

### Unit Tests
- **Location**: `test/grapple/**/*_test.exs`
- **Purpose**: Test individual modules and functions in isolation
- **Coverage**: Core API, storage, query engine, distributed features

### Property-Based Tests
- **Location**: `test/grapple/property_test.exs`
- **Tool**: StreamData
- **Purpose**: Test graph algorithms with generated inputs to verify invariants
- **Features**:
  - Node and edge operation properties
  - Graph traversal properties
  - Invariant testing (stats, memory, IDs)

### Integration Tests
- **Location**: `test/integration/**/*_test.exs`
- **Tag**: `@moduletag :integration`
- **Purpose**: End-to-end workflow testing
- **Scenarios**:
  - Social network workflows
  - Project management workflows
  - Knowledge graph workflows
  - Performance under load

## Running Tests

### All Tests
```bash
# Run all tests except integration tests
mix test

# Run all tests including integration tests
mix test --include integration

# Run with coverage
mix test --cover
```

### Specific Test Types
```bash
# Run only unit tests
mix test test/grapple/

# Run only integration tests
mix test --only integration

# Run only property-based tests
mix test test/grapple/property_test.exs

# Run specific test file
mix test test/grapple/query/executor_test.exs

# Run specific test by line number
mix test test/grapple_test.exs:28
```

### Coverage Reports
```bash
# Generate HTML coverage report
mix coveralls.html

# View report
open cover/excoveralls.html

# Generate JSON coverage report
mix coveralls.json

# Upload to Codecov (in CI)
mix coveralls.post
```

## Test Organization

### Core API Tests (`test/grapple_test.exs`)
- Node operations (create, retrieve, find)
- Edge operations (create, retrieve, find by label)
- Statistics
- Traversal and pathfinding
- Query operations
- Performance benchmarks

### Storage Tests (`test/grapple/storage/ets_graph_store_test.exs`)
- Node CRUD operations
- Edge CRUD operations
- Property indexing
- Label indexing
- Statistics and memory usage
- Concurrent operations

### Query Engine Tests (`test/grapple/query/executor_test.exs`)
- MATCH queries
- Property filtering
- Graph traversal (depth, direction)
- Path finding
- Error handling

### Distributed Feature Tests
- **Cluster Manager** (`test/grapple/distributed/cluster_manager_test.exs`)
  - Cluster formation and joining
  - Cluster information retrieval
  - Status monitoring
- **Health Monitor** (`test/grapple/distributed/health_monitor_test.exs`)
  - Node health checks
  - Health status reporting
  - Monitoring over time

### Performance Tests (`test/grapple/performance/`)
- **Monitor Tests**: Real-time monitoring functionality
- **Profiler Tests**: Memory profiling and analysis

## Property-Based Testing

Grapple uses StreamData for property-based testing to verify graph algorithm properties:

```elixir
property "creating a node always returns a positive integer ID" do
  check all(
          name <- string(:alphanumeric, min_length: 1, max_length: 50),
          age <- integer(1..150),
          max_runs: 100
        ) do
    properties = %{name: name, age: age}
    assert {:ok, node_id} = Grapple.create_node(properties)
    assert is_integer(node_id)
    assert node_id > 0
  end
end
```

### Property Categories
1. **Node Operations**: Creation, retrieval, property uniqueness
2. **Edge Operations**: Creation, label indexing, property preservation
3. **Graph Traversal**: Depth behavior, direction symmetry
4. **Invariants**: Stats accuracy, memory growth, ID uniqueness

## Integration Testing

Integration tests verify end-to-end workflows:

```elixir
test "end-to-end social network scenario" do
  # 1. Create users
  {:ok, alice_id} = Grapple.create_node(%{name: "Alice", role: "Engineer"})

  # 2. Create relationships
  {:ok, _} = Grapple.create_edge(alice_id, bob_id, "knows")

  # 3. Query and verify
  {:ok, engineers} = Grapple.find_nodes_by_property(:role, "Engineer")
  assert length(engineers) == 2
end
```

## Test Coverage

Current test coverage by module:

| Module | Coverage | Lines | Status |
|--------|----------|-------|--------|
| `Grapple` | 100% | 577 | ✅ Excellent |
| `Grapple.Application` | 75% | 45 | ✅ Good |
| `Grapple.Storage.EtsGraphStore` | ~85% | 450+ | ✅ Good |
| `Grapple.Query.Executor` | ~70% | 350+ | ⚠️ Needs improvement |
| `Grapple.Cluster.NodeManager` | 51% | 110 | ⚠️ Needs improvement |
| `Grapple.Distributed.*` | 0-57% | 2500+ | ⚠️ Needs more tests |
| `Grapple.CLI.*` | 0-3% | 950+ | ⚠️ CLI testing needed |

**Overall Coverage**: ~40-50% (significant improvement from <10%)

## Continuous Integration

GitHub Actions CI pipeline runs:

1. **Test Matrix**:
   - Elixir 1.16, 1.17, 1.18
   - OTP 26, 27
   - Ubuntu latest

2. **Test Steps**:
   - Unit tests
   - Integration tests
   - Property-based tests
   - Coverage reporting
   - Code quality checks

3. **Quality Checks**:
   - Format checking
   - Unused dependencies
   - Security vulnerabilities (via `mix deps.audit`)
   - Documentation generation

## Writing New Tests

### Unit Test Template
```elixir
defmodule Grapple.MyModuleTest do
  use ExUnit.Case

  setup do
    # Setup code
    :ok
  end

  describe "my_function/1" do
    test "handles valid input" do
      assert MyModule.my_function(:valid) == {:ok, :result}
    end

    test "handles invalid input" do
      assert MyModule.my_function(:invalid) == {:error, :reason}
    end
  end
end
```

### Property-Based Test Template
```elixir
property "my function preserves invariant" do
  check all(
          input <- my_generator(),
          max_runs: 100
        ) do
    result = my_function(input)
    assert invariant_holds?(result)
  end
end
```

### Integration Test Template
```elixir
@moduletag :integration

test "complete workflow" do
  # 1. Setup
  {:ok, resource} = create_resource()

  # 2. Perform operations
  {:ok, result} = perform_operations(resource)

  # 3. Verify end state
  assert result matches expected_state
end
```

## Best Practices

### Test Isolation
- Use `setup` blocks to initialize state
- Clear ETS tables between tests
- Use unique identifiers for test data

### Test Coverage Goals
- **Critical paths**: 100% coverage
- **Core API**: >95% coverage
- **Supporting modules**: >80% coverage
- **Integration workflows**: Key scenarios covered

### Performance Testing
- Include performance assertions in integration tests
- Use benchmarks (see `PERFORMANCE.md`) for detailed profiling
- Monitor test suite execution time

### Error Testing
- Test both success and failure paths
- Verify error messages and types
- Test edge cases and boundary conditions

## Common Test Patterns

### Testing Async Operations
```elixir
test "async operation completes" do
  task = Task.async(fn -> long_running_operation() end)
  assert {:ok, result} = Task.await(task, 5000)
end
```

### Testing Concurrent Access
```elixir
test "handles concurrent operations" do
  tasks = Enum.map(1..100, fn i ->
    Task.async(fn -> create_node(%{id: i}) end)
  end)

  results = Enum.map(tasks, &Task.await/1)
  assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)
end
```

### Testing Graph Algorithms
```elixir
test "finds shortest path" do
  # Create graph
  nodes = create_graph_structure()

  # Find path
  {:ok, path} = find_path(start, finish)

  # Verify path properties
  assert hd(path) == start
  assert List.last(path) == finish
  assert is_shortest_path?(path, start, finish)
end
```

## Troubleshooting

### Tests Failing Locally
1. Ensure dependencies are up to date: `mix deps.get`
2. Clean build: `mix clean && mix compile`
3. Check for dirty ETS state: Restart IEx session

### Flaky Tests
1. Check for timing issues in async operations
2. Ensure proper test isolation
3. Add appropriate timeouts for async operations

### Coverage Issues
1. Identify untested paths: `mix coveralls.detail`
2. Add missing test cases
3. Remove dead code

## Additional Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/)
- [StreamData Documentation](https://hexdocs.pm/stream_data/)
- [ExCoveralls Documentation](https://hexdocs.pm/excoveralls/)
- [Property-Based Testing Guide](https://elixirschool.com/en/lessons/libraries/stream_data)

## Contributing Tests

When contributing to Grapple:

1. **All new features require tests**
2. **Maintain or improve coverage**
3. **Add integration tests for workflows**
4. **Property tests for algorithms**
5. **Update this guide for new patterns**

Run the full test suite before submitting PRs:

```bash
# Full test run with coverage
mix test --include integration --cover

# Verify CI will pass
mix format --check-formatted
mix compile --warnings-as-errors
```

---

For questions about testing, please open an issue on GitHub.
