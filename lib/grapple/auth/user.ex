defmodule Grapple.Auth.User do
  @moduledoc """
  User management for Grapple authentication.

  Handles user creation, storage, password hashing, and role management.
  Users are stored in ETS for high-performance access.
  """

  alias Grapple.Auth.AuditLog

  @users_table :grapple_users
  @username_index :grapple_username_index

  defstruct [:id, :username, :password_hash, :roles, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: String.t(),
          username: String.t(),
          password_hash: String.t(),
          roles: [atom()],
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Initializes the user storage tables.
  """
  def init do
    # Create users table
    :ets.new(@users_table, [:set, :public, :named_table, read_concurrency: true])
    # Create username index for fast lookups
    :ets.new(@username_index, [:set, :public, :named_table, read_concurrency: true])
    :ok
  end

  @doc """
  Creates a new user with the specified username, password, and roles.
  """
  def create(username, password, roles \\ [:read_only]) do
    # Check if username already exists
    case :ets.lookup(@username_index, username) do
      [{^username, _user_id}] ->
        {:error, :username_taken}

      [] ->
        user_id = generate_user_id()
        password_hash = hash_password(password)
        now = DateTime.utc_now()

        user = %__MODULE__{
          id: user_id,
          username: username,
          password_hash: password_hash,
          roles: roles,
          created_at: now,
          updated_at: now
        }

        :ets.insert(@users_table, {user_id, user})
        :ets.insert(@username_index, {username, user_id})

        AuditLog.log(:user_created, user_id, %{username: username, roles: roles})

        {:ok, user}
    end
  end

  @doc """
  Finds a user by their unique ID.
  """
  def find_by_id(user_id) do
    case :ets.lookup(@users_table, user_id) do
      [{^user_id, user}] -> {:ok, user}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Finds a user by their username.
  """
  def find_by_username(username) do
    case :ets.lookup(@username_index, username) do
      [{^username, user_id}] ->
        find_by_id(user_id)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Verifies a password against a user's stored hash.
  """
  def verify_password(%__MODULE__{password_hash: hash}, password) do
    Bcrypt.verify_pass(password, hash)
  end

  @doc """
  Adds a role to a user.
  """
  def add_role(user_id, role) do
    with {:ok, user} <- find_by_id(user_id) do
      updated_user = %{
        user
        | roles: Enum.uniq([role | user.roles]),
          updated_at: DateTime.utc_now()
      }

      :ets.insert(@users_table, {user_id, updated_user})

      AuditLog.log(:role_assigned, user_id, %{role: role})

      {:ok, updated_user}
    end
  end

  @doc """
  Removes a role from a user.
  """
  def remove_role(user_id, role) do
    with {:ok, user} <- find_by_id(user_id) do
      updated_user = %{
        user
        | roles: List.delete(user.roles, role),
          updated_at: DateTime.utc_now()
      }

      :ets.insert(@users_table, {user_id, updated_user})

      AuditLog.log(:role_revoked, user_id, %{role: role})

      {:ok, updated_user}
    end
  end

  @doc """
  Lists all users in the system.
  """
  def list_all do
    :ets.tab2list(@users_table)
    |> Enum.map(fn {_id, user} -> user end)
  end

  @doc """
  Deletes a user from the system.
  """
  def delete(user_id) do
    case find_by_id(user_id) do
      {:ok, user} ->
        :ets.delete(@users_table, user_id)
        :ets.delete(@username_index, user.username)

        AuditLog.log(:user_deleted, user_id, %{username: user.username})

        :ok

      {:error, :not_found} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Changes a user's password after verifying the old password.
  """
  def change_password(user_id, old_password, new_password) do
    with {:ok, user} <- find_by_id(user_id),
         true <- verify_password(user, old_password) do
      new_hash = hash_password(new_password)

      updated_user = %{
        user
        | password_hash: new_hash,
          updated_at: DateTime.utc_now()
      }

      :ets.insert(@users_table, {user_id, updated_user})

      AuditLog.log(:password_changed, user_id, %{})

      {:ok, updated_user}
    else
      {:error, :not_found} ->
        {:error, :user_not_found}

      false ->
        {:error, :invalid_password}
    end
  end

  # Private functions

  defp generate_user_id do
    "user_#{:erlang.unique_integer([:positive, :monotonic])}"
  end

  defp hash_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end
end
