defmodule Grapple.Auth.Permissions do
  @moduledoc """
  Role-based access control (RBAC) permissions for Grapple.

  Defines permissions for different roles and provides authorization checks.
  """

  alias Grapple.Auth.User

  @custom_roles_table :grapple_custom_roles

  # Built-in role definitions
  @role_permissions %{
    admin: [
      :create_node,
      :read_node,
      :update_node,
      :delete_node,
      :create_edge,
      :read_edge,
      :update_edge,
      :delete_edge,
      :run_analytics,
      :manage_users,
      :manage_roles,
      :view_audit_logs,
      :manage_cluster,
      :execute_query,
      :visualize_graph
    ],
    read_write: [
      :create_node,
      :read_node,
      :update_node,
      :delete_node,
      :create_edge,
      :read_edge,
      :update_edge,
      :delete_edge,
      :execute_query,
      :visualize_graph
    ],
    read_only: [
      :read_node,
      :read_edge,
      :execute_query,
      :visualize_graph
    ],
    analytics: [
      :read_node,
      :read_edge,
      :run_analytics,
      :execute_query,
      :visualize_graph
    ]
  }

  @doc """
  Initializes the custom roles storage.
  """
  def init do
    :ets.new(@custom_roles_table, [:set, :public, :named_table, read_concurrency: true])
    :ok
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def can?(%User{roles: roles}, permission) do
    Enum.any?(roles, fn role ->
      has_permission?(role, permission)
    end)
  end

  @doc """
  Defines a custom role with specific permissions.
  """
  def define_role(role_name, permissions) when is_atom(role_name) and is_list(permissions) do
    :ets.insert(@custom_roles_table, {role_name, permissions})
    :ok
  end

  @doc """
  Gets all permissions for a specific role.
  """
  def get_role_permissions(role) do
    case Map.get(@role_permissions, role) do
      nil ->
        # Check custom roles
        case :ets.lookup(@custom_roles_table, role) do
          [{^role, permissions}] -> permissions
          [] -> []
        end

      permissions ->
        permissions
    end
  end

  @doc """
  Lists all available roles (built-in and custom).
  """
  def list_roles do
    built_in_roles = Map.keys(@role_permissions)

    custom_roles =
      :ets.tab2list(@custom_roles_table)
      |> Enum.map(fn {role, _perms} -> role end)

    Enum.uniq(built_in_roles ++ custom_roles)
  end

  @doc """
  Gets all permissions across all roles.
  """
  def list_all_permissions do
    @role_permissions
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
  end

  # Private functions

  defp has_permission?(role, permission) do
    permissions = get_role_permissions(role)
    permission in permissions
  end
end
