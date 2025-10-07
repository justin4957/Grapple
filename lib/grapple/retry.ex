defmodule Grapple.Retry do
  @moduledoc """
  Retry mechanism with exponential backoff for transient failures.

  Provides configurable retry logic for operations that may fail temporarily
  due to network issues, cluster unavailability, or other transient errors.
  """

  require Logger
  alias Grapple.Error

  @default_max_attempts 3
  @default_base_delay_ms 100
  @default_max_delay_ms 5_000
  @default_backoff_factor 2

  @type retry_options :: [
          max_attempts: pos_integer(),
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer(),
          backoff_factor: number(),
          on_retry: (pos_integer(), term() -> any())
        ]

  @doc """
  Executes a function with retry logic and exponential backoff.

  ## Options

  - `:max_attempts` - Maximum number of retry attempts (default: 3)
  - `:base_delay_ms` - Initial delay in milliseconds (default: 100)
  - `:max_delay_ms` - Maximum delay between retries (default: 5000)
  - `:backoff_factor` - Multiplier for delay after each retry (default: 2)
  - `:on_retry` - Callback function called before each retry attempt

  ## Examples

      # Retry with defaults
      Grapple.Retry.with_retry(fn ->
        risky_operation()
      end)

      # Custom retry configuration
      Grapple.Retry.with_retry(fn ->
        risky_operation()
      end, max_attempts: 5, base_delay_ms: 200)

      # With callback on retry
      Grapple.Retry.with_retry(fn ->
        risky_operation()
      end, on_retry: fn attempt, error ->
        Logger.warning("Retry attempt \#{attempt}: \#{inspect(error)}")
      end)
  """
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)
    backoff_factor = Keyword.get(opts, :backoff_factor, @default_backoff_factor)
    on_retry_callback = Keyword.get(opts, :on_retry)

    do_retry(fun, 1, max_attempts, base_delay_ms, max_delay_ms, backoff_factor, on_retry_callback)
  end

  @doc """
  Executes a function with retry logic only if the error is retryable.

  Uses `Grapple.Error.retryable?/1` to determine if an error should be retried.
  """
  def with_retry_if_retryable(fun, opts \\ []) when is_function(fun, 0) do
    result = fun.()

    case result do
      {:ok, _value} = success ->
        success

      {:error, _reason, _message, _opts} = error ->
        if Error.retryable?(error) do
          with_retry(fun, opts)
        else
          error
        end

      {:error, _reason} = error ->
        # Simple error format - not retryable by default
        error
    end
  end

  @doc """
  Calculates the delay for a given retry attempt using exponential backoff.
  """
  def calculate_delay(attempt, base_delay_ms, max_delay_ms, backoff_factor) do
    delay = trunc(base_delay_ms * :math.pow(backoff_factor, attempt - 1))
    min(delay, max_delay_ms)
  end

  @doc """
  Wraps a distributed operation with retry logic and circuit breaker pattern.

  Automatically retries on cluster unavailability, network errors, and timeouts.
  """
  def with_distributed_retry(fun, opts \\ []) when is_function(fun, 0) do
    default_opts =
      Keyword.merge(
        [
          max_attempts: 5,
          base_delay_ms: 200,
          max_delay_ms: 10_000,
          on_retry: &log_distributed_retry/2
        ],
        opts
      )

    with_retry(fun, default_opts)
  end

  # Private functions
  defp do_retry(_fun, attempt, max_attempts, _base_delay_ms, _max_delay_ms, _backoff_factor, _on_retry_callback)
       when attempt > max_attempts do
    Logger.error("Max retry attempts (#{max_attempts}) exceeded")

    Error.timeout_error("retry", max_attempts)
  end

  defp do_retry(fun, attempt, max_attempts, base_delay_ms, max_delay_ms, backoff_factor, on_retry_callback) do
    case safe_execute(fun) do
      {:ok, _value} = success ->
        if attempt > 1 do
          Logger.info("Operation succeeded after #{attempt - 1} retries")
        end

        success

      {:error, _reason, _message, _opts} = error ->
        if Error.retryable?(error) and attempt < max_attempts do
          delay = calculate_delay(attempt, base_delay_ms, max_delay_ms, backoff_factor)

          if on_retry_callback do
            on_retry_callback.(attempt, error)
          else
            Logger.warning(
              "Retry attempt #{attempt}/#{max_attempts} after #{delay}ms: #{Error.format_error(error)}"
            )
          end

          Process.sleep(delay)

          do_retry(
            fun,
            attempt + 1,
            max_attempts,
            base_delay_ms,
            max_delay_ms,
            backoff_factor,
            on_retry_callback
          )
        else
          Logger.error("Operation failed permanently: #{Error.format_error(error)}")
          error
        end

      {:error, _reason} = simple_error ->
        # Simple error format - not retryable
        Logger.error("Operation failed with non-retryable error: #{inspect(simple_error)}")
        simple_error

      other ->
        # Unexpected result format
        Logger.error("Unexpected result from operation: #{inspect(other)}")
        Error.validation_error("Unexpected operation result", result: other)
    end
  end

  defp safe_execute(fun) do
    try do
      fun.()
    rescue
      error ->
        Logger.error("Exception during operation: #{inspect(error)}")
        Error.validation_error("Operation raised exception", exception: error)
    end
  end

  defp log_distributed_retry(attempt, error) do
    Logger.warning(
      "Distributed operation retry #{attempt}: #{Error.format_error(error)}"
    )
  end
end
