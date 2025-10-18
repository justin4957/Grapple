defmodule Grapple.Auth.Guard do
  @moduledoc """
  Authorization guards for protecting Grapple operations.

  Provides decorators and helpers to enforce permission checks on graph operations.
  """

  alias Grapple.Auth
  alias Grapple.Auth.AuditLog

  @doc """
  Checks if a user has permission to perform an operation.

  If authorized, executes the provided function. Otherwise, logs the denial
  and returns an unauthorized error.

  ## Parameters

  - `user_id` - User's unique ID
  - `permission` - Required permission atom
  - `operation` - Function to execute if authorized

  ## Returns

  - Result of operation function if authorized
  - `{:error, :unauthorized}` if not authorized

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("test_user", "pass", [:admin])
      iex> Grapple.Auth.Guard.check_permission(user.id, :create_node, fn ->
      ...>   {:ok, "node_created"}
      ...> end)
      {:ok, "node_created"}

      iex> {:ok, user} = Grapple.Auth.register("readonly", "pass", [:read_only])
      iex> Grapple.Auth.Guard.check_permission(user.id, :delete_node, fn ->
      ...>   {:ok, "should_not_execute"}
      ...> end)
      {:error, :unauthorized}
  """
  def check_permission(user_id, permission, operation) when is_function(operation, 0) do
    case Auth.authorize(user_id, permission) do
      :ok ->
        operation.()

      {:error, :unauthorized} = error ->
        AuditLog.log(:permission_denied, user_id, %{
          permission: permission,
          timestamp: DateTime.utc_now()
        })

        error

      error ->
        error
    end
  end

  @doc """
  Requires authentication and permission to execute an operation.

  This is a convenience function that combines token validation and permission checking.

  ## Parameters

  - `token` - JWT token string
  - `permission` - Required permission atom
  - `operation` - Function to execute if authorized (receives user as argument)

  ## Returns

  - Result of operation function if authorized
  - `{:error, :unauthorized}` if not authorized
  - `{:error, :invalid_token}` if token is invalid

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("token_user", "pass", [:read_write])
      iex> {:ok, token, _} = Grapple.Auth.login("token_user", "pass")
      iex> Grapple.Auth.Guard.require_permission(token, :create_node, fn validated_user ->
      ...>   {:ok, "created_by_" <> validated_user.username}
      ...> end)
      {:ok, "created_by_token_user"}
  """
  def require_permission(token, permission, operation) when is_function(operation, 1) do
    with {:ok, user} <- Auth.validate_token(token),
         :ok <- Auth.authorize(user.id, permission) do
      operation.(user)
    else
      {:error, :unauthorized} = error ->
        AuditLog.log(:permission_denied, nil, %{
          permission: permission,
          reason: "Token validation or authorization failed"
        })

        error

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Wraps an operation with audit logging.

  Logs both successful and failed operations for security monitoring.

  ## Parameters

  - `event_type` - Type of event being performed
  - `user_id` - User performing the operation
  - `metadata` - Additional context
  - `operation` - Function to execute

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("audited", "pass", [:admin])
      iex> Grapple.Auth.Guard.with_audit_log(:node_created, user.id, %{node_id: 123}, fn ->
      ...>   {:ok, "created"}
      ...> end)
      {:ok, "created"}
  """
  def with_audit_log(event_type, user_id, metadata, operation) when is_function(operation, 0) do
    result = operation.()

    enhanced_metadata =
      metadata
      |> Map.put(:result, result)
      |> Map.put(:timestamp, DateTime.utc_now())

    AuditLog.log(event_type, user_id, enhanced_metadata)

    result
  end
end
