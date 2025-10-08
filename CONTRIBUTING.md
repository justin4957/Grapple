# Contributing to Grapple

Thank you for your interest in contributing to Grapple! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Pull Request Process](#pull-request-process)
6. [Coding Standards](#coding-standards)
7. [Testing Guidelines](#testing-guidelines)
8. [Documentation](#documentation)
9. [Community](#community)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful and professional in all interactions.

## Getting Started

### Prerequisites

- Elixir 1.18 or later
- Erlang/OTP 27 or later
- Git

### First Time Setup

```bash
# Clone the repository
git clone https://github.com/justin4957/Grapple.git
cd grapple

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests to ensure everything works
mix test

# Start the interactive shell
iex -S mix
```

## Development Setup

We provide a development setup script to make getting started easier:

```bash
# Run the development setup script
./scripts/dev-setup.sh
```

This script will:
- Check for required Elixir and Erlang versions
- Install all dependencies
- Set up pre-commit hooks
- Run initial tests
- Generate documentation

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

When creating a bug report, include:
- Clear, descriptive title
- Steps to reproduce the issue
- Expected vs actual behavior
- Elixir/Erlang versions
- Any relevant logs or error messages

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When suggesting an enhancement:
- Use a clear, descriptive title
- Provide detailed description of the proposed functionality
- Explain why this enhancement would be useful
- Include examples if applicable

### Contributing Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add or update tests as needed
5. Ensure all tests pass (`mix test`)
6. Ensure code is properly formatted (`mix format`)
7. Update documentation if needed
8. Commit your changes with descriptive messages
9. Push to your fork
10. Open a Pull Request

## Pull Request Process

### Before Submitting

- [ ] All tests pass (`mix test`)
- [ ] Code is properly formatted (`mix format --check-formatted`)
- [ ] No compilation warnings (`mix compile --warnings-as-errors`)
- [ ] Documentation is updated
- [ ] Changelog is updated (if applicable)
- [ ] Commit messages are clear and descriptive

### PR Requirements

1. **Clear Description**: Explain what changes you made and why
2. **Link Issues**: Reference any related issues
3. **Tests**: Include tests for new functionality
4. **Documentation**: Update relevant documentation
5. **No Breaking Changes**: Avoid breaking changes when possible. If necessary, clearly document them.

### Review Process

- PRs require approval from at least one maintainer
- Address review comments promptly
- Keep PRs focused and reasonably sized
- Be patient - reviews may take a few days

## Coding Standards

### Elixir Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide):

```elixir
# Good: Use descriptive variable names
def calculate_total_price(items, discount_rate) do
  items
  |> Enum.map(&calculate_item_price/1)
  |> Enum.sum()
  |> apply_discount(discount_rate)
end

# Bad: Single-letter variables (except in obvious contexts)
def calc(i, d) do
  # ...
end
```

### Code Organization

- **One module per file**: Keep modules in separate files
- **Logical grouping**: Group related functions together
- **Private functions last**: Place private functions after public ones
- **Module documentation**: Every public module should have `@moduledoc`
- **Function documentation**: Public functions should have `@doc`

### Naming Conventions

- **Modules**: PascalCase (`Grapple.Query.Executor`)
- **Functions**: snake_case (`create_node/1`)
- **Variables**: snake_case (`node_id`)
- **Atoms**: snake_case (`:ok`, `:error`)
- **Constants**: SCREAMING_SNAKE_CASE module attributes

## Testing Guidelines

### Test Coverage

- Aim for >80% test coverage for new code
- All public functions should have tests
- Include both positive and negative test cases
- Test edge cases and error conditions

### Test Organization

```elixir
defmodule Grapple.SomeModuleTest do
  use ExUnit.Case, async: true

  describe "function_name/arity" do
    test "specific behavior being tested" do
      # Arrange
      input = setup_test_data()

      # Act
      result = SomeModule.function_name(input)

      # Assert
      assert result == expected_value
    end
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/grapple/some_module_test.exs

# Run tests with coverage
mix coveralls

# Run tests with detailed output
mix test --trace

# Run integration tests
mix test --only integration

# Run property-based tests
mix test test/grapple/property_test.exs
```

## Documentation

### Code Documentation

```elixir
defmodule Grapple.Example do
  @moduledoc """
  Brief one-line description.

  Detailed explanation of what this module does,
  its responsibilities, and how it fits into the system.

  ## Examples

      iex> Example.do_something(arg)
      {:ok, result}
  """

  @doc """
  Brief function description.

  More detailed explanation if needed.

  ## Parameters

  - `param1` - Description of parameter 1
  - `param2` - Description of parameter 2

  ## Returns

  - `{:ok, result}` - Success case description
  - `{:error, reason}` - Error case description

  ## Examples

      iex> Example.function_name(arg1, arg2)
      {:ok, result}
  """
  @spec function_name(type1, type2) :: {:ok, result} | {:error, atom()}
  def function_name(param1, param2) do
    # Implementation
  end
end
```

### Updating Documentation

- Update relevant markdown files in the repository
- Update module/function documentation in code
- Add examples for new features
- Update the CHANGELOG.md

### Generating Documentation

```bash
# Generate HTML documentation
mix docs

# View documentation locally
open doc/index.html
```

## Community

### Getting Help

- **Documentation**: Check the [Complete User Guide](GUIDE.md)
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions and ideas

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions, ideas, and general discussion
- **Pull Requests**: Code contributions and reviews

## Areas to Contribute

We welcome contributions in many areas:

### Core Features
- **Storage Layer**: ETS optimizations, indexing improvements
- **Query Engine**: Query optimization, new query language features
- **Analytics**: New graph algorithms, performance improvements
- **Distributed Systems**: Replication strategies, cluster management

### Analytics Algorithms
Our analytics engine (see `lib/grapple/analytics/`) uses established algorithms:
- PageRank: Power iteration method with configurable parameters
- Betweenness: Brandes' algorithm for efficient computation
- Connected Components: Union-Find with path compression
- Triangle Counting: For clustering coefficient

Contributions welcome:
- Eigenvector centrality
- Louvain algorithm for community detection
- k-core decomposition
- Shortest path variants (k-shortest, all-shortest)

### Documentation & Examples
- New use case examples
- Performance benchmarks
- Tutorial improvements
- API documentation

### Testing
- Property-based tests for graph invariants
- Stress tests for distributed features
- Performance regression tests
- Integration test scenarios

## Additional Resources

- [README.md](README.md) - Project overview
- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture guide
- [GUIDE.md](GUIDE.md) - Complete user guide
- [TESTING.md](TESTING.md) - Testing infrastructure guide
- [PERFORMANCE.md](PERFORMANCE.md) - Performance monitoring guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [Architecture Overview](guides/advanced/architecture.md) - System design
- [Graph Analytics Guide](guides/examples/graph-analytics.md) - Analytics algorithms and usage

## License

By contributing to Grapple, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Grapple! Your efforts help make this project better for everyone.
