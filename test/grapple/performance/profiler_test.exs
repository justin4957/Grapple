defmodule Grapple.Performance.ProfilerTest do
  use ExUnit.Case
  alias Grapple.Performance.Profiler

  setup do
    # Ensure the ETS graph store is started
    case Grapple.Storage.EtsGraphStore.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Clear any existing data
    try do
      :ets.delete_all_objects(:grapple_nodes)
      :ets.delete_all_objects(:grapple_edges)
      :ets.delete_all_objects(:grapple_node_edges_out)
      :ets.delete_all_objects(:grapple_node_edges_in)
      :ets.delete_all_objects(:grapple_property_index)
      :ets.delete_all_objects(:grapple_label_index)
    catch
      _ -> :ok
    end

    :ok
  end

  describe "get_memory_snapshot/0" do
    test "returns memory usage information" do
      snapshot = Profiler.get_memory_snapshot()

      assert Map.has_key?(snapshot, :total_memory)
      assert Map.has_key?(snapshot, :process_memory)
      assert Map.has_key?(snapshot, :ets_memory)
      assert Map.has_key?(snapshot, :ets_tables)

      assert is_integer(snapshot.total_memory)
      assert snapshot.total_memory > 0
    end

    test "includes ETS table information" do
      snapshot = Profiler.get_memory_snapshot()

      assert Map.has_key?(snapshot.ets_tables, :grapple_nodes)
      assert Map.has_key?(snapshot.ets_tables, :grapple_edges)

      nodes_info = snapshot.ets_tables.grapple_nodes
      assert Map.has_key?(nodes_info, :size)
      assert Map.has_key?(nodes_info, :memory)
    end
  end

  describe "profile_operation/2" do
    test "profiles an operation and returns metrics" do
      profile =
        Profiler.profile_operation(:test_create_node, fn ->
          Grapple.create_node(%{name: "Test"})
        end)

      assert Map.has_key?(profile, :operation)
      assert Map.has_key?(profile, :duration_us)
      assert Map.has_key?(profile, :memory_before)
      assert Map.has_key?(profile, :memory_after)
      assert Map.has_key?(profile, :memory_delta)

      assert profile.operation == :test_create_node
      assert profile.duration_us > 0
    end

    test "captures successful operation results" do
      profile =
        Profiler.profile_operation(:test_success, fn ->
          {:ok, 42}
        end)

      assert profile.result == {:ok, {:ok, 42}}
    end

    test "captures operation errors" do
      profile =
        Profiler.profile_operation(:test_error, fn ->
          raise "test error"
        end)

      assert match?({:error, _}, profile.result)
    end
  end

  describe "profiling sessions" do
    test "can start and generate reports" do
      {:ok, session_id} = Profiler.start_session()

      # Do some operations
      Profiler.record_operation(session_id, :test_op, %{foo: "bar"})
      :timer.sleep(10)

      {:ok, report} = Profiler.generate_report(session_id)

      assert Map.has_key?(report, :session_id)
      assert Map.has_key?(report, :duration_ms)
      assert Map.has_key?(report, :operations_count)
      assert Map.has_key?(report, :memory_delta)

      assert report.operations_count == 1
    end

    test "tracks multiple operations in a session" do
      {:ok, session_id} = Profiler.start_session()

      Profiler.record_operation(session_id, :op1)
      Profiler.record_operation(session_id, :op2)
      Profiler.record_operation(session_id, :op3)

      {:ok, report} = Profiler.generate_report(session_id)

      assert report.operations_count == 3
      assert length(report.operations) == 3
    end
  end

  describe "analyze_memory_usage/0" do
    test "provides memory analysis" do
      # Create some data
      Enum.each(1..100, fn i ->
        Grapple.create_node(%{id: i, name: "Node#{i}"})
      end)

      analysis = Profiler.analyze_memory_usage()

      assert Map.has_key?(analysis, :snapshot)
      assert Map.has_key?(analysis, :stats)
      assert Map.has_key?(analysis, :memory_per_node)
      assert Map.has_key?(analysis, :memory_per_edge)
      assert Map.has_key?(analysis, :table_efficiency)
    end

    test "calculates per-node and per-edge memory" do
      # Create nodes and edges
      {:ok, node1} = Grapple.create_node(%{name: "Alice"})
      {:ok, node2} = Grapple.create_node(%{name: "Bob"})
      Grapple.create_edge(node1, node2, "knows")

      analysis = Profiler.analyze_memory_usage()

      assert is_integer(analysis.memory_per_node)
      assert is_integer(analysis.memory_per_edge)
    end

    test "analyzes table efficiency" do
      Enum.each(1..50, fn i ->
        Grapple.create_node(%{id: i})
      end)

      analysis = Profiler.analyze_memory_usage()

      assert Map.has_key?(analysis.table_efficiency, :grapple_nodes)

      efficiency = analysis.table_efficiency.grapple_nodes

      assert Map.has_key?(efficiency, :avg_item_size)
      assert Map.has_key?(efficiency, :efficiency)
      assert efficiency.efficiency in [:excellent, :good, :acceptable, :needs_optimization]
    end
  end

  describe "regression_test/1" do
    test "runs regression tests without baseline" do
      result = Profiler.regression_test()

      assert Map.has_key?(result, :timestamp)
      assert Map.has_key?(result, :results)
      assert Map.has_key?(result, :baseline_metrics)

      # Check specific operations were tested
      assert Map.has_key?(result.results, :create_node)
      assert Map.has_key?(result.results, :get_node)
    end

    test "compares against baseline metrics" do
      baseline = %{
        create_node: 1000,
        get_node: 500
      }

      result = Profiler.regression_test(baseline)

      create_node_result = result.results.create_node
      assert Map.has_key?(create_node_result, :regression_status)
      assert create_node_result.regression_status in [:ok, :regression_detected, :no_baseline]
    end
  end
end
