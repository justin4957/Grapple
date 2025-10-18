# Authentication & Authorization

Grapple provides comprehensive JWT-based authentication and role-based access control (RBAC) to secure your graph database in multi-user and production deployments.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [Authorization (RBAC)](#authorization-rbac)
- [Audit Logging](#audit-logging)
- [API Reference](#api-reference)
- [Best Practices](#best-practices)

## Overview

Grapple's security system provides:

- **JWT Token Authentication**: Secure token-based authentication using Guardian
- **Password Security**: Bcrypt hashing with automatic salting
- **Role-Based Access Control**: Fine-grained permissions system
- **Built-in Roles**: Pre-configured roles for common use cases
- **Custom Roles**: Define application-specific roles and permissions
- **Audit Logging**: Comprehensive logging of security events
- **Token Management**: Token generation, validation, and revocation

## Quick Start

### 1. Register a User

```elixir
{:ok, user} = Grapple.Auth.register("alice", "secure_password", [:read_write])
# => {:ok, %Grapple.Auth.User{id: "user_1", username: "alice", ...}}
```

### 2. Login and Get Token

```elixir
{:ok, token, claims} = Grapple.Auth.login("alice", "secure_password")
# => {:ok, "eyJhbGc...", %{"sub" => "user_1", ...}}
```

### 3. Use Token for Operations

```elixir
# Validate token
{:ok, user} = Grapple.Auth.validate_token(token)

# Check permission
case Grapple.Auth.authorize(user.id, :create_node) do
  :ok -> Grapple.create_node(%{name: "Data"})
  {:error, :unauthorized} -> {:error, "Permission denied"}
end
```

## Authentication

### User Registration

Create new users with username, password, and optional roles:

```elixir
# Register with default read_only role
{:ok, user} = Grapple.Auth.register("bob", "password123")

# Register with specific roles
{:ok, admin} = Grapple.Auth.register("admin_user", "admin_pass", [:admin])

# Register with multiple roles
{:ok, analyst} = Grapple.Auth.register("data_analyst", "pass", [:analytics, :read_only])
```

### Login

Authenticate users and receive JWT tokens:

```elixir
case Grapple.Auth.login("alice", "password") do
  {:ok, token, claims} ->
    # Token is valid for 30 days by default
    IO.puts("Authentication successful")
    IO.inspect(claims)

  {:error, :invalid_credentials} ->
    IO.puts("Invalid username or password")
end
```

### Token Validation

Validate JWT tokens to retrieve user information:

```elixir
case Grapple.Auth.validate_token(token) do
  {:ok, user} ->
    IO.puts("User: #{user.username}")
    IO.puts("Roles: #{inspect(user.roles)}")

  {:error, :token_expired} ->
    IO.puts("Token has expired")

  {:error, :invalid_token} ->
    IO.puts("Invalid token")
end
```

### Logout

Revoke tokens to invalidate them:

```elixir
:ok = Grapple.Auth.logout(token)
```

### Password Management

Change user passwords securely:

```elixir
{:ok, user} = Grapple.Auth.change_password(
  user_id,
  "old_password",
  "new_password"
)
```

## Authorization (RBAC)

### Built-in Roles

Grapple includes four pre-configured roles:

#### `:admin`
Full access to all operations:
- Create, read, update, delete nodes and edges
- Run analytics
- Manage users and roles
- View audit logs
- Manage cluster

```elixir
{:ok, admin} = Grapple.Auth.register("admin", "pass", [:admin])
```

#### `:read_write`
Can create and modify graph data:
- Create, read, update, delete nodes and edges
- Execute queries
- Visualize graphs

```elixir
{:ok, editor} = Grapple.Auth.register("editor", "pass", [:read_write])
```

#### `:read_only`
Read-only access to graph data:
- Read nodes and edges
- Execute read-only queries
- Visualize graphs

```elixir
{:ok, viewer} = Grapple.Auth.register("viewer", "pass", [:read_only])
```

#### `:analytics`
Read access plus analytics:
- Read nodes and edges
- Run analytics algorithms
- Execute queries
- Create visualizations

```elixir
{:ok, analyst} = Grapple.Auth.register("analyst", "pass", [:analytics])
```

### Permission Checking

Check if a user has permission to perform an action:

```elixir
# Simple boolean check
if Grapple.Auth.can?(user_id, :create_node) do
  Grapple.create_node(%{name: "Test"})
end

# Pattern matching
case Grapple.Auth.authorize(user_id, :delete_node) do
  :ok ->
    Grapple.delete_node(node_id)

  {:error, :unauthorized} ->
    Logger.warning("User #{user_id} attempted unauthorized deletion")
    {:error, "Permission denied"}

  {:error, :user_not_found} ->
    {:error, "User not found"}
end
```

### Permission Guards

Use guards to protect operations:

```elixir
# Simple guard
Grapple.Auth.Guard.check_permission(user_id, :create_node, fn ->
  Grapple.create_node(%{data: "secure"})
end)

# Token-based guard with user context
Grapple.Auth.Guard.require_permission(token, :create_node, fn user ->
  Grapple.create_node(%{
    data: "secure",
    created_by: user.username
  })
end)

# With audit logging
Grapple.Auth.Guard.with_audit_log(:node_created, user_id, %{node_id: 123}, fn ->
  create_and_index_node()
end)
```

### Role Management

Assign and revoke roles dynamically:

```elixir
# Assign a role
{:ok, user} = Grapple.Auth.assign_role(user_id, :analytics)

# Revoke a role
{:ok, user} = Grapple.Auth.revoke_role(user_id, :admin)

# Get user roles
{:ok, roles} = Grapple.Auth.get_user_roles(user_id)
IO.inspect(roles)  # [:read_write, :analytics]
```

### Custom Roles

Define application-specific roles with custom permissions:

```elixir
# Define a custom role
Grapple.Auth.define_role(:data_engineer, [
  :read_nodes,
  :read_edges,
  :create_nodes,
  :create_edges,
  :run_analytics,
  :create_visualizations
])

# Assign custom role to user
{:ok, user} = Grapple.Auth.register("engineer", "pass", [:data_engineer])

# Check custom permission
Grapple.Auth.can?(user.id, :create_visualizations)  # => true
```

### Available Permissions

Core permissions include:

**Node Operations**:
- `:create_node` - Create new nodes
- `:read_node` - Read node data
- `:update_node` - Update node properties
- `:delete_node` - Delete nodes

**Edge Operations**:
- `:create_edge` - Create new edges
- `:read_edge` - Read edge data
- `:update_edge` - Update edge properties
- `:delete_edge` - Delete edges

**Analytics**:
- `:run_analytics` - Execute analytics algorithms

**Admin Operations**:
- `:manage_users` - Create, modify, delete users
- `:manage_roles` - Assign and revoke roles
- `:view_audit_logs` - Access audit logs
- `:manage_cluster` - Cluster management operations

**General**:
- `:execute_query` - Execute graph queries
- `:visualize_graph` - Generate graph visualizations

## Audit Logging

All security-sensitive operations are automatically logged:

### Logged Events

- `user_created` - New user registered
- `user_deleted` - User removed from system
- `login_success` - Successful authentication
- `login_failed` - Failed authentication attempt
- `logout` - User logged out
- `password_changed` - Password updated
- `role_assigned` - Role added to user
- `role_revoked` - Role removed from user
- `permission_denied` - Unauthorized access attempt
- `token_revoked` - Token invalidated

### Viewing Audit Logs

```elixir
# Get all logs for a user
logs = Grapple.Auth.AuditLog.get_user_logs(user_id, limit: 50)

# Get recent logs across all users
recent_logs = Grapple.Auth.AuditLog.get_recent_logs(100)

# Filter logs by criteria
logs = Grapple.Auth.AuditLog.get_logs(
  user_id: "user_123",
  event_type: :permission_denied,
  since: DateTime.utc_now() |> DateTime.add(-7, :day),
  limit: 100
)

# Inspect log entries
Enum.each(logs, fn log ->
  IO.puts("#{log.timestamp} - #{log.event_type}")
  IO.inspect(log.metadata)
end)
```

### Clearing Logs

```elixir
# Clear all audit logs (use with caution!)
:ok = Grapple.Auth.AuditLog.clear_logs()
```

## API Reference

### Core Functions

```elixir
# User Management
Grapple.Auth.register(username, password, roles \\ [:read_only])
Grapple.Auth.delete_user(user_id)
Grapple.Auth.list_users()
Grapple.Auth.change_password(user_id, old_password, new_password)

# Authentication
Grapple.Auth.login(username, password)
Grapple.Auth.validate_token(token)
Grapple.Auth.logout(token)

# Authorization
Grapple.Auth.authorize(user_id, permission)
Grapple.Auth.can?(user_id, permission)

# Role Management
Grapple.Auth.get_user_roles(user_id)
Grapple.Auth.assign_role(user_id, role)
Grapple.Auth.revoke_role(user_id, role)
Grapple.Auth.define_role(role_name, permissions)

# Guards
Grapple.Auth.Guard.check_permission(user_id, permission, operation)
Grapple.Auth.Guard.require_permission(token, permission, operation)
Grapple.Auth.Guard.with_audit_log(event_type, user_id, metadata, operation)

# Audit Logs
Grapple.Auth.AuditLog.get_user_logs(user_id, limit \\ 50)
Grapple.Auth.AuditLog.get_recent_logs(limit \\ 100)
Grapple.Auth.AuditLog.get_logs(opts)
Grapple.Auth.AuditLog.clear_logs()
```

## Best Practices

### 1. Use Environment Variables for Secrets

Never hardcode JWT secrets in your code:

```elixir
# config/runtime.exs
config :grapple, Grapple.Auth.Guardian,
  issuer: "grapple",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || raise("GUARDIAN_SECRET_KEY not set"),
  ttl: {30, :days}
```

### 2. Implement Least Privilege

Start with minimal permissions and add as needed:

```elixir
# Default to read_only
{:ok, user} = Grapple.Auth.register("new_user", "pass", [:read_only])

# Upgrade permissions only when necessary
Grapple.Auth.assign_role(user.id, :read_write)
```

### 3. Use Guards for Protected Operations

Wrap sensitive operations with permission checks:

```elixir
defmodule MyApp.SecureGraph do
  def create_secure_node(token, properties) do
    Grapple.Auth.Guard.require_permission(token, :create_node, fn user ->
      {:ok, node_id} = Grapple.create_node(properties)

      # Log the operation
      Logger.info("Node #{node_id} created by #{user.username}")

      {:ok, node_id}
    end)
  end
end
```

### 4. Monitor Audit Logs

Regularly review audit logs for suspicious activity:

```elixir
# Check for failed login attempts
failed_logins = Grapple.Auth.AuditLog.get_logs(
  event_type: :login_failed,
  since: DateTime.utc_now() |> DateTime.add(-1, :hour)
)

if length(failed_logins) > 10 do
  alert_security_team(failed_logins)
end
```

### 5. Rotate Tokens Regularly

Implement token refresh for long-running applications:

```elixir
defmodule MyApp.TokenManager do
  def refresh_if_needed(token) do
    case Grapple.Auth.validate_token(token) do
      {:ok, user} ->
        # Check if token is close to expiry
        # Re-issue new token if needed
        {:ok, new_token, _} = Grapple.Auth.Guardian.encode_and_sign(user)
        {:ok, new_token}

      {:error, :token_expired} ->
        {:error, :expired}
    end
  end
end
```

### 6. Define Application-Specific Roles

Create roles that match your application's needs:

```elixir
# Define roles during application startup
defmodule MyApp.Application do
  def start(_type, _args) do
    # Define custom roles
    Grapple.Auth.define_role(:content_moderator, [
      :read_nodes,
      :read_edges,
      :update_nodes,
      :delete_nodes
    ])

    Grapple.Auth.define_role(:report_viewer, [
      :read_nodes,
      :read_edges,
      :run_analytics,
      :visualize_graph
    ])

    # ... rest of supervision tree
  end
end
```

### 7. Secure Password Requirements

Enforce strong password policies:

```elixir
defmodule MyApp.Auth do
  def register_with_validation(username, password, roles) do
    with :ok <- validate_username(username),
         :ok <- validate_password_strength(password) do
      Grapple.Auth.register(username, password, roles)
    end
  end

  defp validate_password_strength(password) do
    cond do
      String.length(password) < 8 ->
        {:error, "Password must be at least 8 characters"}

      not Regex.match?(~r/[A-Z]/, password) ->
        {:error, "Password must contain uppercase letter"}

      not Regex.match?(~r/[0-9]/, password) ->
        {:error, "Password must contain a number"}

      true ->
        :ok
    end
  end
end
```

## Example: Securing a Web API

```elixir
defmodule MyAppWeb.GraphController do
  use MyAppWeb, :controller

  def create_node(conn, %{"properties" => properties}) do
    # Extract token from Authorization header
    token = get_token_from_header(conn)

    case Grapple.Auth.Guard.require_permission(token, :create_node, fn user ->
           {:ok, node_id} = Grapple.create_node(properties)

           # Audit log with metadata
           Grapple.Auth.Guard.with_audit_log(
             :api_node_created,
             user.id,
             %{node_id: node_id, ip: conn.remote_ip},
             fn -> {:ok, node_id} end
           )
         end) do
      {:ok, node_id} ->
        json(conn, %{success: true, node_id: node_id})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Permission denied"})

      {:error, :invalid_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired token"})
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end
```

## Configuration

Configure Guardian in your config files:

```elixir
# config/config.exs
config :grapple, Grapple.Auth.Guardian,
  issuer: "grapple",
  secret_key: "default_secret_key_change_in_production",
  ttl: {30, :days},
  verify_issuer: true

# config/prod.exs
config :grapple, Grapple.Auth.Guardian,
  secret_key: {System, :get_env, ["GUARDIAN_SECRET_KEY"]}
```

## Troubleshooting

### Token Validation Fails

```elixir
# Check token structure
case Grapple.Auth.Guardian.decode_and_verify(token) do
  {:ok, claims} ->
    IO.inspect(claims, label: "Token claims")

  {:error, reason} ->
    IO.inspect(reason, label: "Decode error")
end
```

### Permission Always Denied

```elixir
# Verify user roles
{:ok, user} = Grapple.Auth.User.find_by_id(user_id)
IO.inspect(user.roles, label: "User roles")

# Check role permissions
Enum.each(user.roles, fn role ->
  perms = Grapple.Auth.Permissions.get_role_permissions(role)
  IO.puts("#{role}: #{inspect(perms)}")
end)
```

### Audit Logs Not Recording

```elixir
# Verify audit log table exists
:ets.info(:grapple_audit_logs)

# Check if application initialized auth
Grapple.Auth.User.init()
Grapple.Auth.Permissions.init()
Grapple.Auth.AuditLog.init()
```

## Related Documentation

- [API Documentation](../README.md#api-reference)
- [Security Best Practices](./security.md)
- [Distributed Mode Security](../README_DISTRIBUTED.md#security)
