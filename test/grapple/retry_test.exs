defmodule Grapple.RetryTest do
  use ExUnit.Case, async: true
  alias Grapple.{Retry, Error}

  describe "with_retry/2" do
    test "returns success on first attempt" do
      fun = fn -> {:ok, :success} end
      assert {:ok, :success} = Retry.with_retry(fun, max_attempts: 3)
    end

    test "retries on retryable errors" do
      # Track number of attempts
      agent_pid = start_supervised!({Agent, fn -> 0 end})

      fun = fn ->
        attempt = Agent.get_and_update(agent_pid, fn count -> {count + 1, count + 1} end)

        if attempt < 3 do
          Error.timeout_error("operation", 100)
        else
          {:ok, :success_after_retries}
        end
      end

      assert {:ok, :success_after_retries} =
               Retry.with_retry(fun, max_attempts: 3, base_delay_ms: 10)

      assert Agent.get(agent_pid, & &1) == 3
    end

    test "gives up after max attempts" do
      fun = fn -> Error.timeout_error("operation", 100) end

      {:error, :timeout, _message, _opts} =
        Retry.with_retry(fun, max_attempts: 2, base_delay_ms: 10)
    end

    test "does not retry non-retryable errors" do
      agent_pid = start_supervised!({Agent, fn -> 0 end})

      fun = fn ->
        Agent.update(agent_pid, &(&1 + 1))
        Error.validation_error("Bad input")
      end

      {:error, :validation_error, _message, _opts} =
        Retry.with_retry(fun, max_attempts: 3, base_delay_ms: 10)

      # Should only attempt once
      assert Agent.get(agent_pid, & &1) == 1
    end

    test "calls on_retry callback" do
      agent_pid = start_supervised!({Agent, fn -> [] end})

      on_retry = fn attempt, _error ->
        Agent.update(agent_pid, fn attempts -> [attempt | attempts] end)
      end

      fun = fn ->
        attempt = Agent.get(agent_pid, &length(&1))

        if attempt < 2 do
          Error.timeout_error("operation", 100)
        else
          {:ok, :success}
        end
      end

      assert {:ok, :success} =
               Retry.with_retry(fun, max_attempts: 3, base_delay_ms: 10, on_retry: on_retry)

      retry_attempts = Agent.get(agent_pid, & &1) |> Enum.reverse()
      assert retry_attempts == [1, 2]
    end

    test "handles exceptions in the function" do
      fun = fn -> raise "Something went wrong" end

      {:error, :validation_error, _message, _opts} =
        Retry.with_retry(fun, max_attempts: 2, base_delay_ms: 10)
    end
  end

  describe "calculate_delay/4" do
    test "calculates exponential backoff" do
      # Attempt 1: 100 * 2^0 = 100
      assert Retry.calculate_delay(1, 100, 5000, 2) == 100

      # Attempt 2: 100 * 2^1 = 200
      assert Retry.calculate_delay(2, 100, 5000, 2) == 200

      # Attempt 3: 100 * 2^2 = 400
      assert Retry.calculate_delay(3, 100, 5000, 2) == 400

      # Attempt 4: 100 * 2^3 = 800
      assert Retry.calculate_delay(4, 100, 5000, 2) == 800
    end

    test "respects max delay" do
      # Would be 100 * 2^10 = 102400, but capped at 5000
      assert Retry.calculate_delay(10, 100, 5000, 2) == 5000
    end

    test "supports different backoff factors" do
      # With factor 3: 100 * 3^2 = 900
      assert Retry.calculate_delay(3, 100, 5000, 3) == 900
    end
  end

  describe "with_retry_if_retryable/2" do
    test "returns success immediately" do
      fun = fn -> {:ok, :result} end
      assert {:ok, :result} = Retry.with_retry_if_retryable(fun)
    end

    test "retries only retryable errors" do
      agent_pid = start_supervised!({Agent, fn -> 0 end})

      fun = fn ->
        attempt = Agent.get_and_update(agent_pid, fn count -> {count + 1, count + 1} end)

        if attempt < 2 do
          Error.timeout_error("op", 100)
        else
          {:ok, :success}
        end
      end

      assert {:ok, :success} =
               Retry.with_retry_if_retryable(fun, max_attempts: 3, base_delay_ms: 10)
    end

    test "does not retry non-retryable errors" do
      agent_pid = start_supervised!({Agent, fn -> 0 end})

      fun = fn ->
        Agent.update(agent_pid, &(&1 + 1))
        Error.validation_error("Bad")
      end

      {:error, :validation_error, _message, _opts} =
        Retry.with_retry_if_retryable(fun, max_attempts: 3, base_delay_ms: 10)

      # Should only execute once
      assert Agent.get(agent_pid, & &1) == 1
    end

    test "handles simple error format" do
      fun = fn -> {:error, :not_found} end
      assert {:error, :not_found} = Retry.with_retry_if_retryable(fun)
    end
  end

  describe "with_distributed_retry/2" do
    test "uses distributed-specific defaults" do
      fun = fn -> {:ok, :success} end
      assert {:ok, :success} = Retry.with_distributed_retry(fun)
    end

    test "retries distributed failures" do
      agent_pid = start_supervised!({Agent, fn -> 0 end})

      fun = fn ->
        attempt = Agent.get_and_update(agent_pid, fn count -> {count + 1, count + 1} end)

        if attempt < 2 do
          {:error, :cluster_unavailable, "Cluster down", []}
        else
          {:ok, :recovered}
        end
      end

      assert {:ok, :recovered} =
               Retry.with_distributed_retry(fun, max_attempts: 3, base_delay_ms: 10)
    end
  end
end
