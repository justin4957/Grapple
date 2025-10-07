# Configure ExUnit
ExUnit.start(
  exclude: [:integration],
  formatters: [ExUnit.CLIFormatter],
  max_cases: System.schedulers_online() * 2
)

# Start the application for integration tests
Application.ensure_all_started(:grapple)
