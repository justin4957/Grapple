defmodule Grapple.Performance.MonitorTest do
  use ExUnit.Case
  alias Grapple.Performance.Monitor

  setup do
    # Start the monitor
    case Monitor.start_link() do
      {:ok, pid} -> {:ok, monitor: pid}
      {:error, {:already_started, pid}} -> {:ok, monitor: pid}
    end

    # Reset metrics before each test
    Monitor.reset_metrics()

    :ok
  end

  describe "track/2" do
    test "tracks operation execution time" do
      result =
        Monitor.track(:test_operation, fn ->
          :timer.sleep(10)
          :ok
        end)

      assert result == :ok

      stats = Monitor.get_operation_stats(:test_operation)
      assert stats.count == 1
      assert stats.min_time_us >= 10_000
      assert stats.avg_time_us >= 10_000
    end

    test "tracks multiple operations" do
      Enum.each(1..5, fn _ ->
        Monitor.track(:multiple_ops, fn -> :ok end)
      end)

      stats = Monitor.get_operation_stats(:multiple_ops)
      assert stats.count == 5
    end

    test "returns function result" do
      result = Monitor.track(:test_return, fn -> {:ok, 42} end)
      assert result == {:ok, 42}
    end

    test "tracks errors correctly" do
      assert_raise RuntimeError, fn ->
        Monitor.track(:error_operation, fn ->
          raise "test error"
        end)
      end

      stats = Monitor.get_operation_stats(:error_operation)
      assert stats.count == 1
      assert stats.error_count == 1
    end
  end

  describe "get_metrics/0" do
    test "returns all tracked metrics" do
      Monitor.track(:op1, fn -> :ok end)
      Monitor.track(:op2, fn -> :ok end)

      metrics = Monitor.get_metrics()

      assert Map.has_key?(metrics, :operations)
      assert Map.has_key?(metrics, :uptime_seconds)
      assert Map.has_key?(metrics, :sample_rate)

      assert Map.has_key?(metrics.operations, :op1)
      assert Map.has_key?(metrics.operations, :op2)
    end

    test "calculates percentiles correctly" do
      # Track operations with varying durations
      Enum.each(1..100, fn i ->
        Monitor.track(:percentile_test, fn ->
          :timer.sleep(i)
        end)
      end)

      stats = Monitor.get_operation_stats(:percentile_test)

      assert Map.has_key?(stats, :percentiles)
      assert Map.has_key?(stats.percentiles, :p50)
      assert Map.has_key?(stats.percentiles, :p95)
      assert Map.has_key?(stats.percentiles, :p99)

      # P99 should be greater than P95
      assert stats.percentiles.p99 >= stats.percentiles.p95
      # P95 should be greater than P50
      assert stats.percentiles.p95 >= stats.percentiles.p50
    end
  end

  describe "sampling" do
    test "respects sample rate" do
      Monitor.set_sample_rate(0.0)

      # These should not be tracked
      Enum.each(1..10, fn _ ->
        Monitor.track(:no_sample, fn -> :ok end)
      end)

      stats = Monitor.get_operation_stats(:no_sample)
      assert is_nil(stats)

      # Reset sample rate
      Monitor.set_sample_rate(1.0)
    end

    test "can change sample rate" do
      Monitor.set_sample_rate(0.5)
      assert Monitor.get_sample_rate() == 0.5

      Monitor.set_sample_rate(1.0)
      assert Monitor.get_sample_rate() == 1.0
    end
  end

  describe "reset_metrics/0" do
    test "clears all metrics" do
      Monitor.track(:test, fn -> :ok end)

      stats_before = Monitor.get_operation_stats(:test)
      assert stats_before.count == 1

      Monitor.reset_metrics()

      stats_after = Monitor.get_operation_stats(:test)
      assert is_nil(stats_after)
    end
  end

  describe "throughput calculation" do
    test "calculates operations per second" do
      # Operation with measurable duration
      Enum.each(1..10, fn _ ->
        Monitor.track(:fast_op, fn ->
          # Small delay to ensure non-zero duration
          :timer.sleep(1)
          :ok
        end)
      end)

      stats = Monitor.get_operation_stats(:fast_op)
      assert Map.has_key?(stats, :throughput_per_sec)
      assert stats.throughput_per_sec >= 0
    end
  end
end
