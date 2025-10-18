defmodule Grapple.AuthTest do
  use ExUnit.Case, async: false

  alias Grapple.Auth
  alias Grapple.Auth.{User, Permissions, AuditLog}

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

  describe "register/3" do
    test "creates a new user with valid credentials" do
      assert {:ok, user} = Auth.register("alice", "password123", [:admin])
      assert user.username == "alice"
      assert is_binary(user.password_hash)
      assert :admin in user.roles
    end

    test "creates a user with default read_only role" do
      assert {:ok, user} = Auth.register("bob", "password123")
      assert user.roles == [:read_only]
    end

    test "prevents duplicate usernames" do
      assert {:ok, _user} = Auth.register("charlie", "pass1")
      assert {:error, :username_taken} = Auth.register("charlie", "pass2")
    end

    test "creates user with multiple roles" do
      assert {:ok, user} = Auth.register("multi", "pass", [:admin, :analytics])
      assert :admin in user.roles
      assert :analytics in user.roles
    end
  end

  describe "login/2" do
    test "returns token on successful authentication" do
      {:ok, _user} = Auth.register("alice", "secret123")
      assert {:ok, token, claims} = Auth.login("alice", "secret123")
      assert is_binary(token)
      assert is_map(claims)
    end

    test "returns error for invalid password" do
      {:ok, _user} = Auth.register("bob", "correct_pass")
      assert {:error, :invalid_credentials} = Auth.login("bob", "wrong_pass")
    end

    test "returns error for non-existent user" do
      assert {:error, :invalid_credentials} = Auth.login("nonexistent", "password")
    end
  end

  describe "validate_token/1" do
    test "validates a valid token and returns user" do
      {:ok, user} = Auth.register("charlie", "password")
      {:ok, token, _claims} = Auth.login("charlie", "password")

      assert {:ok, validated_user} = Auth.validate_token(token)
      assert validated_user.id == user.id
      assert validated_user.username == "charlie"
    end

    test "returns error for invalid token" do
      assert {:error, _reason} = Auth.validate_token("invalid_token")
    end
  end

  describe "authorize/2" do
    test "allows admin to perform any action" do
      {:ok, admin} = Auth.register("admin", "pass", [:admin])
      assert :ok = Auth.authorize(admin.id, :create_node)
      assert :ok = Auth.authorize(admin.id, :delete_node)
      assert :ok = Auth.authorize(admin.id, :manage_users)
    end

    test "allows read_write users to create and delete" do
      {:ok, user} = Auth.register("writer", "pass", [:read_write])
      assert :ok = Auth.authorize(user.id, :create_node)
      assert :ok = Auth.authorize(user.id, :delete_edge)
    end

    test "denies read_write users from managing users" do
      {:ok, user} = Auth.register("writer", "pass", [:read_write])
      assert {:error, :unauthorized} = Auth.authorize(user.id, :manage_users)
    end

    test "allows read_only users to read only" do
      {:ok, user} = Auth.register("reader", "pass", [:read_only])
      assert :ok = Auth.authorize(user.id, :read_node)
      assert {:error, :unauthorized} = Auth.authorize(user.id, :create_node)
    end

    test "allows analytics users to read and run analytics" do
      {:ok, user} = Auth.register("analyst", "pass", [:analytics])
      assert :ok = Auth.authorize(user.id, :read_node)
      assert :ok = Auth.authorize(user.id, :run_analytics)
      assert {:error, :unauthorized} = Auth.authorize(user.id, :delete_node)
    end

    test "returns error for non-existent user" do
      assert {:error, :user_not_found} = Auth.authorize("fake_id", :read_node)
    end
  end

  describe "can?/2" do
    test "returns true when user has permission" do
      {:ok, admin} = Auth.register("admin", "pass", [:admin])
      assert Auth.can?(admin.id, :create_node) == true
    end

    test "returns false when user lacks permission" do
      {:ok, reader} = Auth.register("reader", "pass", [:read_only])
      assert Auth.can?(reader.id, :delete_node) == false
    end
  end

  describe "get_user_roles/1" do
    test "returns user's roles" do
      {:ok, user} = Auth.register("multi_role", "pass", [:admin, :analytics])
      assert {:ok, roles} = Auth.get_user_roles(user.id)
      assert :admin in roles
      assert :analytics in roles
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = Auth.get_user_roles("fake_id")
    end
  end

  describe "assign_role/2" do
    test "adds a new role to user" do
      {:ok, user} = Auth.register("upgradeable", "pass", [:read_only])
      assert {:ok, updated} = Auth.assign_role(user.id, :read_write)
      assert :read_only in updated.roles
      assert :read_write in updated.roles
    end

    test "does not duplicate roles" do
      {:ok, user} = Auth.register("existing", "pass", [:admin])
      assert {:ok, updated} = Auth.assign_role(user.id, :admin)
      assert Enum.count(updated.roles, &(&1 == :admin)) == 1
    end
  end

  describe "revoke_role/2" do
    test "removes a role from user" do
      {:ok, user} = Auth.register("downgradeable", "pass", [:admin, :read_write])
      assert {:ok, updated} = Auth.revoke_role(user.id, :admin)
      refute :admin in updated.roles
      assert :read_write in updated.roles
    end

    test "handles revoking non-existent role gracefully" do
      {:ok, user} = Auth.register("simple", "pass", [:read_only])
      assert {:ok, updated} = Auth.revoke_role(user.id, :admin)
      refute :admin in updated.roles
    end
  end

  describe "define_role/2" do
    test "creates a custom role with permissions" do
      assert :ok =
               Auth.define_role(:data_scientist, [
                 :read_nodes,
                 :read_edges,
                 :run_analytics
               ])

      permissions = Permissions.get_role_permissions(:data_scientist)
      assert :read_nodes in permissions
      assert :run_analytics in permissions
    end
  end

  describe "list_users/0" do
    test "returns all users" do
      {:ok, _user1} = Auth.register("user1", "pass1")
      {:ok, _user2} = Auth.register("user2", "pass2")
      {:ok, _user3} = Auth.register("user3", "pass3")

      users = Auth.list_users()
      assert length(users) == 3
      usernames = Enum.map(users, & &1.username)
      assert "user1" in usernames
      assert "user2" in usernames
      assert "user3" in usernames
    end

    test "returns empty list when no users" do
      assert Auth.list_users() == []
    end
  end

  describe "delete_user/1" do
    test "deletes an existing user" do
      {:ok, user} = Auth.register("deletable", "pass")
      assert :ok = Auth.delete_user(user.id)
      assert {:error, :not_found} = User.find_by_id(user.id)
    end

    test "returns error for non-existent user" do
      assert {:error, :user_not_found} = Auth.delete_user("fake_id")
    end
  end

  describe "change_password/3" do
    test "changes password with correct old password" do
      {:ok, user} = Auth.register("password_changer", "old_pass")
      assert {:ok, _updated} = Auth.change_password(user.id, "old_pass", "new_pass")

      # Verify new password works
      assert {:ok, _token, _claims} = Auth.login("password_changer", "new_pass")
    end

    test "rejects change with incorrect old password" do
      {:ok, user} = Auth.register("secure", "correct_pass")
      assert {:error, :invalid_password} = Auth.change_password(user.id, "wrong_pass", "new_pass")
    end

    test "returns error for non-existent user" do
      assert {:error, :user_not_found} = Auth.change_password("fake_id", "old", "new")
    end
  end

  describe "audit logging" do
    test "logs user creation events" do
      {:ok, user} = Auth.register("audited", "pass")
      logs = AuditLog.get_user_logs(user.id)
      assert Enum.any?(logs, &(&1.event_type == :user_created))
    end

    test "logs role assignment events" do
      {:ok, user} = Auth.register("role_user", "pass", [:read_only])
      Auth.assign_role(user.id, :admin)

      logs = AuditLog.get_user_logs(user.id)
      assert Enum.any?(logs, &(&1.event_type == :role_assigned))
    end

    test "logs password change events" do
      {:ok, user} = Auth.register("pwd_user", "old")
      Auth.change_password(user.id, "old", "new")

      logs = AuditLog.get_user_logs(user.id)
      assert Enum.any?(logs, &(&1.event_type == :password_changed))
    end
  end
end
