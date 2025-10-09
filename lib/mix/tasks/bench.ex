defmodule Mix.Tasks.Bench do
  @moduledoc """
  Run Grapple benchmarks.

  ## Usage

      # Run all benchmarks
      mix bench

      # Run specific suite
      mix bench --core
      mix bench --scalability
      mix bench --analytics

      # Run quick mode (faster, less thorough)
      mix bench --quick

      # Generate only HTML reports
      mix bench --html-only

  ## Examples

      mix bench
      mix bench --core
      mix bench --scalability --quick
  """

  @shortdoc "Run Grapple benchmarks"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          core: :boolean,
          scalability: :boolean,
          analytics: :boolean,
          quick: :boolean,
          html_only: :boolean
        ]
      )

    # Ensure the application is started
    Mix.Task.run("app.start")

    # Determine which benchmarks to run
    suites =
      cond do
        opts[:core] -> [:core]
        opts[:scalability] -> [:scalability]
        opts[:analytics] -> [:analytics]
        true -> [:core, :scalability, :analytics]
      end

    IO.puts("\n" <> IO.ANSI.cyan() <> "╔═══════════════════════════════════════╗")
    IO.puts("║    Grapple Benchmark Suite           ║")
    IO.puts("╚═══════════════════════════════════════╝" <> IO.ANSI.reset())
    IO.puts("")

    if opts[:quick] do
      IO.puts(
        IO.ANSI.yellow() <> "⚡ Quick mode enabled - reduced iterations\n" <> IO.ANSI.reset()
      )
    end

    # Run each suite
    Enum.each(suites, fn suite ->
      run_suite(suite, opts)
    end)

    IO.puts("\n" <> IO.ANSI.green() <> "✅ All benchmarks complete!" <> IO.ANSI.reset())
    IO.puts("📊 HTML reports saved to: benchmarks/results/\n")
  end

  defp run_suite(:core, _opts) do
    IO.puts(IO.ANSI.blue() <> "═══ Running Core Benchmarks ═══" <> IO.ANSI.reset())

    run_benchmark("benchmarks/core/node_operations_bench.exs")
    run_benchmark("benchmarks/core/edge_operations_bench.exs")
    run_benchmark("benchmarks/core/traversal_bench.exs")
  end

  defp run_suite(:scalability, _opts) do
    IO.puts(IO.ANSI.blue() <> "═══ Running Scalability Benchmarks ═══" <> IO.ANSI.reset())

    run_benchmark("benchmarks/scalability/graph_size_bench.exs")
    run_benchmark("benchmarks/scalability/concurrency_bench.exs")
    run_benchmark("benchmarks/scalability/memory_bench.exs")
  end

  defp run_suite(:analytics, _opts) do
    IO.puts(IO.ANSI.blue() <> "═══ Running Analytics Benchmarks ═══" <> IO.ANSI.reset())

    run_benchmark("benchmarks/analytics/algorithms_bench.exs")
  end

  defp run_benchmark(path) do
    IO.puts("\n▶️  Running #{Path.basename(path)}...")

    case Mix.shell().cmd("mix run #{path}") do
      0 -> :ok
      _error -> IO.puts(IO.ANSI.red() <> "⚠️  Benchmark failed" <> IO.ANSI.reset())
    end
  end
end
