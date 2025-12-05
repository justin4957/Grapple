defmodule Grapple.Auth.TokenRevocation do
  @moduledoc """
  ETS-based token revocation tracking for Grapple.

  Provides the ability to revoke JWT tokens before their natural expiration,
  enabling secure logout and compromised token invalidation.

  ## How It Works

  When a token is revoked, its JTI (JWT ID) is stored in an ETS table along with
  its expiration timestamp. When validating tokens, the system checks if the JTI
  has been revoked. Expired revocation entries are automatically cleaned up.

  ## Usage

      # Revoke a token (typically called from logout)
      {:ok, :revoked} = Grapple.Auth.TokenRevocation.revoke(token)

      # Check if a JTI has been revoked
      true = Grapple.Auth.TokenRevocation.revoked?("some-jti")

      # Cleanup expired entries (called periodically)
      count = Grapple.Auth.TokenRevocation.cleanup_expired()

  ## Integration

  This module is automatically integrated with:
  - `Grapple.Auth.logout/1` - Revokes tokens on logout
  - `Grapple.Auth.Guardian.resource_from_claims/1` - Checks revocation on validation
  """

  use GenServer
  require Logger

  alias Grapple.Auth.Guardian

  @table :grapple_revoked_tokens
  @cleanup_interval_ms :timer.hours(1)

  # Client API

  @doc """
  Starts the TokenRevocation GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Revokes a JWT token by storing its JTI in the revocation table.

  ## Parameters

  - `token` - The JWT token string to revoke

  ## Returns

  - `{:ok, :revoked}` - Token successfully revoked
  - `{:error, reason}` - If the token cannot be decoded or is invalid

  ## Examples

      iex> {:ok, token, _claims} = Grapple.Auth.login("user", "password")
      iex> Grapple.Auth.TokenRevocation.revoke(token)
      {:ok, :revoked}
  """
  @spec revoke(String.t()) :: {:ok, :revoked} | {:error, term()}
  def revoke(token) when is_binary(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        jti = claims["jti"]
        exp = claims["exp"]

        if jti do
          :ets.insert(@table, {jti, exp})
          Logger.info("Token revoked", jti: jti)
          {:ok, :revoked}
        else
          {:error, :missing_jti}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Revokes a token by its JTI directly.

  Useful when you have the JTI but not the full token.

  ## Parameters

  - `jti` - The JWT ID to revoke
  - `exp` - The expiration timestamp (Unix seconds). Defaults to 30 days from now.

  ## Returns

  - `{:ok, :revoked}` - JTI successfully revoked

  ## Examples

      iex> Grapple.Auth.TokenRevocation.revoke_by_jti("abc123", 1735689600)
      {:ok, :revoked}
  """
  @spec revoke_by_jti(String.t(), integer() | nil) :: {:ok, :revoked}
  def revoke_by_jti(jti, exp \\ nil) when is_binary(jti) do
    # Default to 30 days from now if no expiration provided
    expiration = exp || System.system_time(:second) + 30 * 24 * 60 * 60
    :ets.insert(@table, {jti, expiration})
    Logger.info("Token revoked by JTI", jti: jti)
    {:ok, :revoked}
  end

  @doc """
  Checks if a JTI has been revoked.

  ## Parameters

  - `jti` - The JWT ID to check

  ## Returns

  - `true` if the JTI has been revoked
  - `false` if the JTI has not been revoked

  ## Examples

      iex> Grapple.Auth.TokenRevocation.revoked?("non-existent-jti")
      false

      iex> Grapple.Auth.TokenRevocation.revoke_by_jti("revoked-jti")
      iex> Grapple.Auth.TokenRevocation.revoked?("revoked-jti")
      true
  """
  @spec revoked?(String.t()) :: boolean()
  def revoked?(jti) when is_binary(jti) do
    :ets.member(@table, jti)
  end

  def revoked?(_), do: false

  @doc """
  Removes expired revocation entries from the table.

  Called automatically every hour by the GenServer, but can also be called manually.

  ## Returns

  The number of entries removed.

  ## Examples

      iex> count = Grapple.Auth.TokenRevocation.cleanup_expired()
      iex> is_integer(count)
      true
  """
  @spec cleanup_expired() :: non_neg_integer()
  def cleanup_expired do
    now = System.system_time(:second)

    # Select and delete entries where exp < now
    count =
      :ets.select_delete(@table, [
        {{:"$1", :"$2"}, [{:<, :"$2", now}], [true]}
      ])

    if count > 0 do
      Logger.info("Cleaned up #{count} expired token revocation entries")
    end

    count
  end

  @doc """
  Returns statistics about the revocation table.

  ## Returns

  A map with:
  - `:count` - Number of revoked tokens
  - `:memory_bytes` - Memory usage in bytes

  ## Examples

      iex> stats = Grapple.Auth.TokenRevocation.get_stats()
      iex> is_integer(stats.count)
      true
  """
  @spec get_stats() :: %{count: non_neg_integer(), memory_bytes: non_neg_integer()}
  def get_stats do
    %{
      count: :ets.info(@table, :size),
      memory_bytes: :ets.info(@table, :memory) * :erlang.system_info(:wordsize)
    }
  end

  @doc """
  Checks if the TokenRevocation service is running.

  ## Returns

  - `true` if the GenServer is running
  - `false` otherwise
  """
  @spec running?() :: boolean()
  def running? do
    Process.whereis(__MODULE__) != nil
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("TokenRevocation service started")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end
