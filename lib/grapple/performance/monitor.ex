defmodule Grapple.Performance.Monitor do
  @moduledoc """
  Real-time performance monitoring for Grapple graph operations.

  Provides instrumentation and metrics collection for monitoring performance
  in production environments.

  ## Features

  - Operation timing and throughput tracking
  - Memory usage monitoring
  - Query performance profiling
  - Histogram-based latency analysis
  - Configurable sampling rates

  ## Usage

      # Start monitoring
      Grapple.Performance.Monitor.start_link()

      # Track an operation
      result = Grapple.Performance.Monitor.track(:create_node, fn ->
        Grapple.create_node(%{name: "Alice"})
      end)

      # Get current metrics
      metrics = Grapple.Performance.Monitor.get_metrics()

      # Get operation statistics
      stats = Grapple.Performance.Monitor.get_operation_stats(:create_node)
  """

  use GenServer
  require Logger

  @type operation_name :: atom()
  @type metric_data :: %{
          count: non_neg_integer(),
          total_time_us: non_neg_integer(),
          min_time_us: non_neg_integer(),
          max_time_us: non_neg_integer(),
          avg_time_us: float(),
          percentiles: %{
            p50: non_neg_integer(),
            p95: non_neg_integer(),
            p99: non_neg_integer()
          }
        }

  defmodule State do
    @moduledoc false
    defstruct operations: %{},
              start_time: nil,
              sample_rate: 1.0,
              max_samples: 10_000
  end

  ## Client API

  @doc """
  Starts the performance monitor.

  ## Options

  - `:sample_rate` - Fraction of operations to sample (0.0 to 1.0, default: 1.0)
  - `:max_samples` - Maximum number of samples to keep per operation (default: 10,000)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Tracks the execution time of a function.

  Returns the result of the function execution.

  ## Examples

      result = Grapple.Performance.Monitor.track(:create_node, fn ->
        Grapple.create_node(%{name: "Alice"})
      end)
  """
  @spec track(operation_name(), fun()) :: any()
  def track(operation_name, function) do
    should_sample = :rand.uniform() <= get_sample_rate()

    if should_sample do
      start_time = System.monotonic_time(:microsecond)

      try do
        result = function.()
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        record_operation(operation_name, duration, :ok)
        result
      rescue
        error ->
          end_time = System.monotonic_time(:microsecond)
          duration = end_time - start_time
          record_operation(operation_name, duration, :error)
          reraise error, __STACKTRACE__
      end
    else
      function.()
    end
  end

  @doc """
  Records an operation metric.

  Useful when you want to manually record metrics without wrapping in track/2.
  """
  @spec record_operation(operation_name(), non_neg_integer(), :ok | :error) :: :ok
  def record_operation(operation_name, duration_us, status) do
    GenServer.cast(__MODULE__, {:record, operation_name, duration_us, status})
  end

  @doc """
  Gets all current performance metrics.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Gets statistics for a specific operation.
  """
  @spec get_operation_stats(operation_name()) :: metric_data() | nil
  def get_operation_stats(operation_name) do
    GenServer.call(__MODULE__, {:get_operation_stats, operation_name})
  end

  @doc """
  Resets all performance metrics.
  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    GenServer.call(__MODULE__, :reset_metrics)
  end

  @doc """
  Gets the current sample rate.
  """
  @spec get_sample_rate() :: float()
  def get_sample_rate do
    case Process.whereis(__MODULE__) do
      nil -> 1.0
      _pid -> GenServer.call(__MODULE__, :get_sample_rate)
    end
  end

  @doc """
  Sets the sample rate for monitoring.

  ## Parameters

  - `rate` - Float between 0.0 and 1.0 (0% to 100% sampling)
  """
  @spec set_sample_rate(float()) :: :ok
  def set_sample_rate(rate) when rate >= 0.0 and rate <= 1.0 do
    GenServer.call(__MODULE__, {:set_sample_rate, rate})
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    state = %State{
      operations: %{},
      start_time: System.monotonic_time(:second),
      sample_rate: Keyword.get(opts, :sample_rate, 1.0),
      max_samples: Keyword.get(opts, :max_samples, 10_000)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:record, operation_name, duration_us, status}, state) do
    operations = state.operations

    operation_data =
      Map.get(operations, operation_name, %{
        samples: [],
        count: 0,
        error_count: 0,
        total_time_us: 0,
        min_time_us: nil,
        max_time_us: nil
      })

    new_samples = [duration_us | operation_data.samples]
    # Keep only max_samples most recent samples
    trimmed_samples =
      if length(new_samples) > state.max_samples do
        Enum.take(new_samples, state.max_samples)
      else
        new_samples
      end

    updated_operation =
      operation_data
      |> Map.put(:samples, trimmed_samples)
      |> Map.put(:count, operation_data.count + 1)
      |> Map.put(:error_count, operation_data.error_count + if(status == :error, do: 1, else: 0))
      |> Map.put(:total_time_us, operation_data.total_time_us + duration_us)
      |> Map.put(
        :min_time_us,
        min_value(operation_data.min_time_us, duration_us)
      )
      |> Map.put(
        :max_time_us,
        max_value(operation_data.max_time_us, duration_us)
      )

    updated_operations = Map.put(operations, operation_name, updated_operation)
    {:noreply, %{state | operations: updated_operations}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics =
      state.operations
      |> Enum.map(fn {name, data} ->
        {name, calculate_stats(data)}
      end)
      |> Map.new()

    uptime = System.monotonic_time(:second) - state.start_time

    response = %{
      operations: metrics,
      uptime_seconds: uptime,
      sample_rate: state.sample_rate
    }

    {:reply, response, state}
  end

  @impl true
  def handle_call({:get_operation_stats, operation_name}, _from, state) do
    stats =
      case Map.get(state.operations, operation_name) do
        nil -> nil
        data -> calculate_stats(data)
      end

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:reset_metrics, _from, state) do
    new_state = %{state | operations: %{}, start_time: System.monotonic_time(:second)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_sample_rate, _from, state) do
    {:reply, state.sample_rate, state}
  end

  @impl true
  def handle_call({:set_sample_rate, rate}, _from, state) do
    {:reply, :ok, %{state | sample_rate: rate}}
  end

  ## Private Functions

  defp min_value(nil, value), do: value
  defp min_value(current, value), do: min(current, value)

  defp max_value(nil, value), do: value
  defp max_value(current, value), do: max(current, value)

  defp calculate_stats(%{samples: samples, count: count} = data) when length(samples) > 0 do
    avg_time_us = div(data.total_time_us, count)
    sorted_samples = Enum.sort(samples)

    percentiles = %{
      p50: calculate_percentile(sorted_samples, 0.50),
      p95: calculate_percentile(sorted_samples, 0.95),
      p99: calculate_percentile(sorted_samples, 0.99)
    }

    throughput_per_sec =
      if avg_time_us > 0 do
        Float.round(1_000_000.0 / avg_time_us, 2)
      else
        0.0
      end

    %{
      count: count,
      error_count: Map.get(data, :error_count, 0),
      total_time_us: data.total_time_us,
      min_time_us: data.min_time_us,
      max_time_us: data.max_time_us,
      avg_time_us: avg_time_us,
      throughput_per_sec: throughput_per_sec,
      percentiles: percentiles
    }
  end

  defp calculate_stats(%{count: count}), do: %{count: count}

  defp calculate_percentile(sorted_samples, percentile) do
    count = length(sorted_samples)

    if count == 0 do
      0
    else
      index = trunc(percentile * count)
      index = min(index, count - 1)
      Enum.at(sorted_samples, index)
    end
  end
end
