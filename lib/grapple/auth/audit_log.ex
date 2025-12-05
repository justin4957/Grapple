defmodule Grapple.Auth.AuditLog do
  @moduledoc """
  Audit logging for authentication and authorization events in Grapple.

  Records security-sensitive events for compliance and security monitoring.
  """

  require Logger

  @audit_table :grapple_audit_logs

  defstruct [:id, :event_type, :user_id, :metadata, :timestamp]

  @type event_type ::
          :user_created
          | :user_deleted
          | :login_success
          | :login_failed
          | :logout
          | :password_changed
          | :role_assigned
          | :role_revoked
          | :permission_denied
          | :token_revoked
          | :all_tokens_revoked

  @type t :: %__MODULE__{
          id: String.t(),
          event_type: event_type(),
          user_id: String.t() | nil,
          metadata: map(),
          timestamp: DateTime.t()
        }

  @doc """
  Initializes the audit log storage.
  """
  def init do
    :ets.new(@audit_table, [:ordered_set, :public, :named_table, read_concurrency: true])
    :ok
  end

  @doc """
  Logs an audit event.

  ## Parameters

  - `event_type` - Type of event (atom)
  - `user_id` - ID of the user involved (can be nil for system events)
  - `metadata` - Additional event details (map)

  ## Examples

      iex> Grapple.Auth.AuditLog.log(:login_success, "user_123", %{ip: "192.168.1.1"})
      :ok
  """
  def log(event_type, user_id \\ nil, metadata \\ %{}) do
    log_id = generate_log_id()
    timestamp = DateTime.utc_now()

    entry = %__MODULE__{
      id: log_id,
      event_type: event_type,
      user_id: user_id,
      metadata: metadata,
      timestamp: timestamp
    }

    :ets.insert(@audit_table, {log_id, entry})

    # Also log to Elixir logger for external monitoring systems
    Logger.info(
      "Audit: #{event_type}",
      user_id: user_id,
      metadata: metadata,
      timestamp: timestamp
    )

    :ok
  end

  @doc """
  Retrieves audit logs with optional filtering.

  ## Options

  - `:user_id` - Filter by user ID
  - `:event_type` - Filter by event type
  - `:since` - Filter events after this DateTime
  - `:limit` - Maximum number of logs to return (default: 100)

  ## Examples

      iex> Grapple.Auth.AuditLog.get_logs(user_id: "user_123", limit: 10)
      [...]
  """
  def get_logs(opts \\ []) do
    logs =
      :ets.tab2list(@audit_table)
      |> Enum.map(fn {_id, entry} -> entry end)
      |> apply_filters(opts)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> maybe_limit(Keyword.get(opts, :limit, 100))

    logs
  end

  @doc """
  Gets audit logs for a specific user.
  """
  def get_user_logs(user_id, limit \\ 50) do
    get_logs(user_id: user_id, limit: limit)
  end

  @doc """
  Gets recent audit logs.
  """
  def get_recent_logs(limit \\ 100) do
    get_logs(limit: limit)
  end

  @doc """
  Clears all audit logs (use with caution!).
  """
  def clear_logs do
    :ets.delete_all_objects(@audit_table)
    Logger.warning("All audit logs have been cleared")
    :ok
  end

  # Private functions

  defp generate_log_id do
    "log_#{System.system_time(:microsecond)}_#{:erlang.unique_integer([:positive])}"
  end

  defp apply_filters(logs, []), do: logs

  defp apply_filters(logs, [{:user_id, user_id} | rest]) do
    logs
    |> Enum.filter(&(&1.user_id == user_id))
    |> apply_filters(rest)
  end

  defp apply_filters(logs, [{:event_type, event_type} | rest]) do
    logs
    |> Enum.filter(&(&1.event_type == event_type))
    |> apply_filters(rest)
  end

  defp apply_filters(logs, [{:since, datetime} | rest]) do
    logs
    |> Enum.filter(&(DateTime.compare(&1.timestamp, datetime) == :gt))
    |> apply_filters(rest)
  end

  defp apply_filters(logs, [_unknown | rest]) do
    apply_filters(logs, rest)
  end

  defp maybe_limit(logs, limit) when is_integer(limit) do
    Enum.take(logs, limit)
  end

  defp maybe_limit(logs, _), do: logs
end
