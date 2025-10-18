defmodule Grapple.Auth do
  @moduledoc """
  Authentication and Authorization module for Grapple.

  Provides comprehensive authentication using JWT tokens and role-based access control (RBAC)
  for securing graph operations in multi-user and production deployments.

  ## Features

  - JWT-based authentication with token generation and validation
  - Password hashing using bcrypt
  - Role-based access control (RBAC)
  - User registration and management
  - Audit logging for security events

  ## Roles

  Grapple supports the following built-in roles:

  - `:admin` - Full access to all operations
  - `:read_write` - Can create, update, and delete nodes and edges
  - `:read_only` - Can only read data and run analytics
  - `:analytics` - Can read and run analytics, no graph modifications

  Custom roles can be defined using `define_role/2`.

  ## Examples

      # Register a new user
      {:ok, user} = Grapple.Auth.register("alice", "secure_password", [:read_write])

      # Login and get a token
      {:ok, token, _claims} = Grapple.Auth.login("alice", "secure_password")

      # Validate a token
      {:ok, user} = Grapple.Auth.validate_token(token)

      # Check permissions
      case Grapple.Auth.authorize(user.id, :create_node) do
        :ok -> Grapple.create_node(%{name: "Test"})
        {:error, :unauthorized} -> {:error, "Permission denied"}
      end
  """

  alias Grapple.Auth.{User, Guardian, Permissions}

  @doc """
  Registers a new user with a username, password, and optional roles.

  ## Parameters

  - `username` - Unique username for the user
  - `password` - Plain text password (will be hashed)
  - `roles` - List of role atoms (default: [:read_only])

  ## Returns

  - `{:ok, user}` - Successfully created user
  - `{:error, reason}` - If registration fails

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("alice", "password123", [:admin])
      iex> user.username
      "alice"
      iex> is_binary(user.password_hash)
      true
  """
  def register(username, password, roles \\ [:read_only]) do
    User.create(username, password, roles)
  end

  @doc """
  Authenticates a user and generates a JWT token.

  ## Parameters

  - `username` - User's username
  - `password` - User's password

  ## Returns

  - `{:ok, token, claims}` - Authentication successful with JWT token
  - `{:error, :invalid_credentials}` - Invalid username or password
  - `{:error, :user_not_found}` - User does not exist

  ## Examples

      iex> {:ok, _user} = Grapple.Auth.register("bob", "secret", [:read_write])
      iex> {:ok, token, claims} = Grapple.Auth.login("bob", "secret")
      iex> is_binary(token)
      true
      iex> is_map(claims)
      true
  """
  def login(username, password) do
    with {:ok, user} <- User.find_by_username(username),
         true <- User.verify_password(user, password) do
      Guardian.encode_and_sign(user)
    else
      {:error, :not_found} ->
        # Prevent timing attacks by still hashing
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      false ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Validates a JWT token and returns the associated user.

  ## Parameters

  - `token` - JWT token string

  ## Returns

  - `{:ok, user}` - Token is valid
  - `{:error, reason}` - Token is invalid or expired

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("charlie", "pass", [:analytics])
      iex> {:ok, token, _claims} = Grapple.Auth.login("charlie", "pass")
      iex> {:ok, validated_user} = Grapple.Auth.validate_token(token)
      iex> validated_user.id == user.id
      true
  """
  def validate_token(token) do
    with {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      {:ok, user}
    end
  end

  @doc """
  Logs out a user by revoking their token.

  ## Parameters

  - `token` - JWT token to revoke

  ## Returns

  - `:ok` - Token revoked successfully
  - `{:error, reason}` - If revocation fails
  """
  def logout(token) do
    Guardian.revoke(token)
  end

  @doc """
  Checks if a user has permission to perform an action.

  ## Parameters

  - `user_id` - User's unique ID
  - `permission` - Permission atom to check

  ## Returns

  - `:ok` - User has permission
  - `{:error, :unauthorized}` - User lacks permission
  - `{:error, :user_not_found}` - User does not exist

  ## Examples

      iex> {:ok, admin} = Grapple.Auth.register("admin_user", "admin123", [:admin])
      iex> Grapple.Auth.authorize(admin.id, :create_node)
      :ok

      iex> {:ok, reader} = Grapple.Auth.register("reader", "read123", [:read_only])
      iex> Grapple.Auth.authorize(reader.id, :create_node)
      {:error, :unauthorized}
  """
  def authorize(user_id, permission) do
    with {:ok, user} <- User.find_by_id(user_id),
         true <- Permissions.can?(user, permission) do
      :ok
    else
      {:error, :not_found} ->
        {:error, :user_not_found}

      false ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Checks if a user can perform an action.

  Similar to `authorize/2` but returns a boolean.

  ## Examples

      iex> {:ok, admin} = Grapple.Auth.register("admin2", "pass", [:admin])
      iex> Grapple.Auth.can?(admin.id, :delete_node)
      true

      iex> {:ok, reader} = Grapple.Auth.register("reader2", "pass", [:read_only])
      iex> Grapple.Auth.can?(reader.id, :create_edge)
      false
  """
  def can?(user_id, permission) do
    case authorize(user_id, permission) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Gets all roles assigned to a user.

  ## Parameters

  - `user_id` - User's unique ID

  ## Returns

  - `{:ok, roles}` - List of role atoms
  - `{:error, :user_not_found}` - User does not exist

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("multi_role", "pass", [:admin, :analytics])
      iex> {:ok, roles} = Grapple.Auth.get_user_roles(user.id)
      iex> :admin in roles
      true
      iex> :analytics in roles
      true
  """
  def get_user_roles(user_id) do
    case User.find_by_id(user_id) do
      {:ok, user} -> {:ok, user.roles}
      error -> error
    end
  end

  @doc """
  Assigns a role to a user.

  ## Parameters

  - `user_id` - User's unique ID
  - `role` - Role atom to assign

  ## Returns

  - `{:ok, user}` - Role assigned successfully
  - `{:error, reason}` - If assignment fails

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("upgradeable", "pass", [:read_only])
      iex> {:ok, updated} = Grapple.Auth.assign_role(user.id, :read_write)
      iex> :read_write in updated.roles
      true
  """
  def assign_role(user_id, role) do
    User.add_role(user_id, role)
  end

  @doc """
  Revokes a role from a user.

  ## Parameters

  - `user_id` - User's unique ID
  - `role` - Role atom to revoke

  ## Returns

  - `{:ok, user}` - Role revoked successfully
  - `{:error, reason}` - If revocation fails

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("downgradeable", "pass", [:admin, :read_write])
      iex> {:ok, updated} = Grapple.Auth.revoke_role(user.id, :admin)
      iex> :admin in updated.roles
      false
      iex> :read_write in updated.roles
      true
  """
  def revoke_role(user_id, role) do
    User.remove_role(user_id, role)
  end

  @doc """
  Defines a custom role with specific permissions.

  ## Parameters

  - `role_name` - Atom representing the role
  - `permissions` - List of permission atoms

  ## Examples

      iex> Grapple.Auth.define_role(:data_scientist, [
      ...>   :read_nodes,
      ...>   :read_edges,
      ...>   :run_analytics,
      ...>   :create_visualizations
      ...> ])
      :ok
  """
  def define_role(role_name, permissions) do
    Permissions.define_role(role_name, permissions)
  end

  @doc """
  Lists all users in the system.

  ## Returns

  - List of user maps

  ## Examples

      iex> {:ok, _} = Grapple.Auth.register("user1", "pass1", [:read_only])
      iex> {:ok, _} = Grapple.Auth.register("user2", "pass2", [:admin])
      iex> users = Grapple.Auth.list_users()
      iex> length(users) >= 2
      true
  """
  def list_users do
    User.list_all()
  end

  @doc """
  Deletes a user from the system.

  ## Parameters

  - `user_id` - User's unique ID

  ## Returns

  - `:ok` - User deleted successfully
  - `{:error, :user_not_found}` - User does not exist

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("deletable", "pass", [:read_only])
      iex> Grapple.Auth.delete_user(user.id)
      :ok
      iex> Grapple.Auth.delete_user(user.id)
      {:error, :user_not_found}
  """
  def delete_user(user_id) do
    User.delete(user_id)
  end

  @doc """
  Changes a user's password.

  ## Parameters

  - `user_id` - User's unique ID
  - `old_password` - Current password for verification
  - `new_password` - New password to set

  ## Returns

  - `{:ok, user}` - Password changed successfully
  - `{:error, :invalid_password}` - Old password is incorrect
  - `{:error, :user_not_found}` - User does not exist

  ## Examples

      iex> {:ok, user} = Grapple.Auth.register("password_changer", "old_pass", [:read_only])
      iex> {:ok, _} = Grapple.Auth.change_password(user.id, "old_pass", "new_pass")
      iex> {:ok, _token, _claims} = Grapple.Auth.login("password_changer", "new_pass")
  """
  def change_password(user_id, old_password, new_password) do
    User.change_password(user_id, old_password, new_password)
  end
end
