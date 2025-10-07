defmodule Grapple.Performance.Profiler do
  @moduledoc """
  Memory and performance profiling utilities for Grapple.

  Provides tools for analyzing memory usage, detecting performance bottlenecks,
  and generating profiling reports.

  ## Features

  - Memory usage profiling and analysis
  - ETS table memory tracking
  - Query execution profiling
  - Performance regression detection
  - Detailed profiling reports

  ## Usage

      # Start a profiling session
      {:ok, session} = Grapple.Performance.Profiler.start_session()

      # Run operations to profile
      Grapple.create_node(%{name: "Test"})

      # Generate profiling report
      report = Grapple.Performance.Profiler.generate_report(session)
      IO.inspect(report, pretty: true)
  """

  require Logger

  @type session_id :: reference()
  @type profiling_session :: %{
          id: session_id(),
          start_time: integer(),
          initial_memory: map(),
          operations: list()
        }

  @doc """
  Starts a new profiling session.

  Returns a session ID that can be used to generate reports.
  """
  @spec start_session() :: {:ok, session_id()}
  def start_session do
    session_id = make_ref()

    initial_state = %{
      id: session_id,
      start_time: System.monotonic_time(:millisecond),
      initial_memory: get_memory_snapshot(),
      operations: []
    }

    # Store in process dictionary for this session
    Process.put({__MODULE__, session_id}, initial_state)

    {:ok, session_id}
  end

  @doc """
  Records an operation in a profiling session.
  """
  @spec record_operation(session_id(), atom(), map()) :: :ok
  def record_operation(session_id, operation_name, metadata \\ %{}) do
    case Process.get({__MODULE__, session_id}) do
      nil ->
        {:error, :session_not_found}

      session ->
        operation_record = %{
          name: operation_name,
          timestamp: System.monotonic_time(:millisecond),
          memory: get_memory_snapshot(),
          metadata: metadata
        }

        updated_session = %{
          session
          | operations: [operation_record | session.operations]
        }

        Process.put({__MODULE__, session_id}, updated_session)
        :ok
    end
  end

  @doc """
  Generates a profiling report for a session.
  """
  @spec generate_report(session_id()) :: {:ok, map()} | {:error, atom()}
  def generate_report(session_id) do
    case Process.get({__MODULE__, session_id}) do
      nil ->
        {:error, :session_not_found}

      session ->
        end_time = System.monotonic_time(:millisecond)
        final_memory = get_memory_snapshot()

        report = %{
          session_id: session_id,
          duration_ms: end_time - session.start_time,
          initial_memory: session.initial_memory,
          final_memory: final_memory,
          memory_delta: calculate_memory_delta(session.initial_memory, final_memory),
          operations_count: length(session.operations),
          operations: Enum.reverse(session.operations),
          recommendations: generate_recommendations(session, final_memory)
        }

        {:ok, report}
    end
  end

  @doc """
  Gets current memory usage snapshot.
  """
  @spec get_memory_snapshot() :: map()
  def get_memory_snapshot do
    %{
      total_memory: :erlang.memory(:total),
      process_memory: :erlang.memory(:processes),
      ets_memory: :erlang.memory(:ets),
      atom_memory: :erlang.memory(:atom),
      binary_memory: :erlang.memory(:binary),
      ets_tables: get_ets_table_memory()
    }
  end

  @doc """
  Gets detailed memory usage for all Grapple ETS tables.
  """
  @spec get_ets_table_memory() :: map()
  def get_ets_table_memory do
    tables = [
      :grapple_nodes,
      :grapple_edges,
      :grapple_node_edges_out,
      :grapple_node_edges_in,
      :grapple_property_index,
      :grapple_label_index
    ]

    tables
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)

        {table,
         %{
           size: Keyword.get(info, :size, 0),
           memory: Keyword.get(info, :memory, 0)
         }}
      rescue
        _ ->
          {table, %{size: 0, memory: 0}}
      end
    end)
    |> Map.new()
  end

  @doc """
  Analyzes memory usage patterns and identifies potential issues.
  """
  @spec analyze_memory_usage() :: map()
  def analyze_memory_usage do
    snapshot = get_memory_snapshot()
    stats = get_graph_stats()

    analysis = %{
      snapshot: snapshot,
      stats: stats,
      memory_per_node: calculate_memory_per_node(snapshot, stats),
      memory_per_edge: calculate_memory_per_edge(snapshot, stats),
      table_efficiency: analyze_table_efficiency(snapshot.ets_tables),
      recommendations: []
    }

    analysis
    |> add_memory_recommendations()
  end

  @doc """
  Profiles a specific operation and returns detailed metrics.
  """
  @spec profile_operation(atom(), fun()) :: map()
  def profile_operation(operation_name, function) do
    initial_memory = get_memory_snapshot()
    start_time = System.monotonic_time(:microsecond)

    result =
      try do
        {:ok, function.()}
      rescue
        error -> {:error, error}
      end

    end_time = System.monotonic_time(:microsecond)
    final_memory = get_memory_snapshot()

    %{
      operation: operation_name,
      duration_us: end_time - start_time,
      result: result,
      memory_before: initial_memory,
      memory_after: final_memory,
      memory_delta: calculate_memory_delta(initial_memory, final_memory),
      allocations: final_memory.total_memory - initial_memory.total_memory
    }
  end

  @doc """
  Runs a performance regression test suite.

  Compares current performance against baseline metrics.
  """
  @spec regression_test(map()) :: map()
  def regression_test(baseline_metrics \\ %{}) do
    tests = [
      {:create_node,
       fn ->
         Grapple.create_node(%{name: "Test", role: "Engineer", value: 42})
       end},
      {:get_node,
       fn ->
         {:ok, id} = Grapple.create_node(%{name: "Test"})
         Grapple.get_node(id)
       end},
      {:find_nodes_by_property,
       fn ->
         Grapple.create_node(%{category: "test"})
         Grapple.find_nodes_by_property(:category, "test")
       end}
    ]

    results =
      tests
      |> Enum.map(fn {name, test_fn} ->
        # Run multiple iterations
        iterations = 100

        {time_us, _results} =
          :timer.tc(fn ->
            Enum.each(1..iterations, fn _ -> test_fn.() end)
          end)

        avg_time = div(time_us, iterations)

        regression_status =
          case Map.get(baseline_metrics, name) do
            nil ->
              :no_baseline

            baseline_avg ->
              threshold = baseline_avg * 1.2

              if avg_time > threshold do
                :regression_detected
              else
                :ok
              end
          end

        {name,
         %{
           avg_time_us: avg_time,
           iterations: iterations,
           regression_status: regression_status
         }}
      end)
      |> Map.new()

    %{
      timestamp: DateTime.utc_now(),
      results: results,
      baseline_metrics: baseline_metrics
    }
  end

  ## Private Functions

  defp calculate_memory_delta(initial, final) do
    %{
      total: final.total_memory - initial.total_memory,
      process: final.process_memory - initial.process_memory,
      ets: final.ets_memory - initial.ets_memory,
      binary: final.binary_memory - initial.binary_memory
    }
  end

  defp get_graph_stats do
    try do
      Grapple.get_stats()
    rescue
      _ ->
        %{total_nodes: 0, total_edges: 0, memory_usage: %{}}
    end
  end

  defp calculate_memory_per_node(snapshot, stats) do
    if stats.total_nodes > 0 do
      node_memory = get_in(snapshot.ets_tables, [:grapple_nodes, :memory]) || 0
      div(node_memory, stats.total_nodes)
    else
      0
    end
  end

  defp calculate_memory_per_edge(snapshot, stats) do
    if stats.total_edges > 0 do
      edge_memory = get_in(snapshot.ets_tables, [:grapple_edges, :memory]) || 0
      div(edge_memory, stats.total_edges)
    else
      0
    end
  end

  defp analyze_table_efficiency(ets_tables) do
    ets_tables
    |> Enum.map(fn {table, data} ->
      avg_item_size =
        if data.size > 0 do
          div(data.memory, data.size)
        else
          0
        end

      {table, %{avg_item_size: avg_item_size, efficiency: calculate_efficiency(avg_item_size)}}
    end)
    |> Map.new()
  end

  defp calculate_efficiency(avg_item_size) do
    cond do
      avg_item_size < 50 -> :excellent
      avg_item_size < 100 -> :good
      avg_item_size < 200 -> :acceptable
      true -> :needs_optimization
    end
  end

  defp add_memory_recommendations(analysis) do
    recommendations = []

    recommendations =
      if analysis.memory_per_node > 200 do
        [
          "Consider reducing node property sizes - average per-node memory is high"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if analysis.memory_per_edge > 150 do
        [
          "Consider reducing edge property sizes - average per-edge memory is high"
          | recommendations
        ]
      else
        recommendations
      end

    total_ets_memory = analysis.snapshot.ets_memory

    recommendations =
      if total_ets_memory > 1_000_000_000 do
        [
          "ETS memory usage is high (>1GB) - consider implementing data archival"
          | recommendations
        ]
      else
        recommendations
      end

    %{analysis | recommendations: recommendations}
  end

  defp generate_recommendations(session, final_memory) do
    recommendations = []

    memory_growth =
      final_memory.total_memory - session.initial_memory.total_memory

    recommendations =
      if memory_growth > 100_000_000 do
        ["High memory growth detected (#{div(memory_growth, 1_000_000)}MB)" | recommendations]
      else
        recommendations
      end

    recommendations =
      if length(session.operations) > 1000 do
        ["Large number of operations tracked - consider sampling" | recommendations]
      else
        recommendations
      end

    recommendations
  end
end
