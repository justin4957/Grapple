defmodule Grapple.Auth.GuardTest do
  use ExUnit.Case, async: false

  alias Grapple.Auth
  alias Grapple.Auth.{Guard, AuditLog}

  setup do
    # Clean up tables before each test (tables are created by Application)
    :ets.delete_all_objects(:grapple_users)
    :ets.delete_all_objects(:grapple_username_index)
    :ets.delete_all_objects(:grapple_custom_roles)
    :ets.delete_all_objects(:grapple_audit_logs)

    # Clean up tables after each test
    on_exit(fn ->
      :ets.delete_all_objects(:grapple_users)
      :ets.delete_all_objects(:grapple_username_index)
      :ets.delete_all_objects(:grapple_custom_roles)
      :ets.delete_all_objects(:grapple_audit_logs)
    end)

    :ok
  end

  describe "check_permission/3" do
    test "executes operation when user has permission" do
      {:ok, admin} = Auth.register("admin", "pass", [:admin])

      result =
        Guard.check_permission(admin.id, :create_node, fn ->
          {:ok, "node_created"}
        end)

      assert result == {:ok, "node_created"}
    end

    test "returns unauthorized error when user lacks permission" do
      {:ok, reader} = Auth.register("reader", "pass", [:read_only])

      result =
        Guard.check_permission(reader.id, :delete_node, fn ->
          {:ok, "should_not_execute"}
        end)

      assert result == {:error, :unauthorized}
    end

    test "logs permission denial to audit log" do
      {:ok, reader} = Auth.register("reader", "pass", [:read_only])

      Guard.check_permission(reader.id, :delete_node, fn ->
        {:ok, "nope"}
      end)

      logs = AuditLog.get_user_logs(reader.id)
      assert Enum.any?(logs, &(&1.event_type == :permission_denied))
    end
  end

  describe "require_permission/3" do
    test "executes operation with valid token and permission" do
      {:ok, _user} = Auth.register("writer", "pass", [:read_write])
      {:ok, token, _} = Auth.login("writer", "pass")

      result =
        Guard.require_permission(token, :create_node, fn validated_user ->
          {:ok, "created_by_#{validated_user.username}"}
        end)

      assert result == {:ok, "created_by_writer"}
    end

    test "returns unauthorized for insufficient permissions" do
      {:ok, _user} = Auth.register("reader", "pass", [:read_only])
      {:ok, token, _} = Auth.login("reader", "pass")

      result =
        Guard.require_permission(token, :delete_node, fn _user ->
          {:ok, "should_not_execute"}
        end)

      assert result == {:error, :unauthorized}
    end

    test "returns invalid_token for bad token" do
      result =
        Guard.require_permission("bad_token", :read_node, fn _user ->
          {:ok, "should_not_execute"}
        end)

      assert result == {:error, :invalid_token}
    end
  end

  describe "with_audit_log/4" do
    test "logs successful operation execution" do
      {:ok, user} = Auth.register("logger", "pass", [:admin])

      result =
        Guard.with_audit_log(:node_created, user.id, %{node_id: 123}, fn ->
          {:ok, "created"}
        end)

      assert result == {:ok, "created"}

      logs = AuditLog.get_user_logs(user.id)
      node_creation_log = Enum.find(logs, &(&1.event_type == :node_created))
      assert node_creation_log != nil
      assert node_creation_log.metadata.node_id == 123
    end

    test "logs operation failures" do
      {:ok, user} = Auth.register("failer", "pass", [:admin])

      result =
        Guard.with_audit_log(:operation_failed, user.id, %{reason: "test"}, fn ->
          {:error, "failed"}
        end)

      assert result == {:error, "failed"}

      logs = AuditLog.get_user_logs(user.id)
      failure_log = Enum.find(logs, &(&1.event_type == :operation_failed))
      assert failure_log != nil
    end
  end
end
