defmodule Grapple.Auth.TokenRevocationTest do
  use ExUnit.Case, async: false

  alias Grapple.Auth.TokenRevocation

  setup do
    # Clear any existing revoked tokens for test isolation
    # We can't directly clear ETS, but we can work with fresh JTIs
    :ok
  end

  describe "revoke/1" do
    test "revokes a valid token" do
      # Create a test user and get a token
      {:ok, user} =
        Grapple.Auth.register("revoke_test_#{System.unique_integer()}", "password", [:read_only])

      {:ok, token, _claims} = Grapple.Auth.login(user.username, "password")

      # Revoke the token
      assert {:ok, :revoked} = TokenRevocation.revoke(token)
    end

    test "returns error for invalid token" do
      assert {:error, _reason} = TokenRevocation.revoke("invalid-token")
    end

    test "revoked token has its JTI stored" do
      {:ok, user} =
        Grapple.Auth.register("revoke_jti_test_#{System.unique_integer()}", "password", [
          :read_only
        ])

      {:ok, token, claims} = Grapple.Auth.login(user.username, "password")

      jti = claims["jti"]
      assert is_binary(jti), "Token should have a JTI claim"

      # Before revocation
      refute TokenRevocation.revoked?(jti)

      # Revoke
      {:ok, :revoked} = TokenRevocation.revoke(token)

      # After revocation
      assert TokenRevocation.revoked?(jti)
    end
  end

  describe "revoke_by_jti/2" do
    test "revokes a JTI directly" do
      jti = "test_jti_#{System.unique_integer()}"

      refute TokenRevocation.revoked?(jti)

      {:ok, :revoked} = TokenRevocation.revoke_by_jti(jti)

      assert TokenRevocation.revoked?(jti)
    end

    test "accepts custom expiration" do
      jti = "test_jti_exp_#{System.unique_integer()}"
      exp = System.system_time(:second) + 3600

      {:ok, :revoked} = TokenRevocation.revoke_by_jti(jti, exp)

      assert TokenRevocation.revoked?(jti)
    end
  end

  describe "revoked?/1" do
    test "returns false for non-revoked JTI" do
      refute TokenRevocation.revoked?("non-existent-jti-#{System.unique_integer()}")
    end

    test "returns true for revoked JTI" do
      jti = "revoked_test_#{System.unique_integer()}"
      TokenRevocation.revoke_by_jti(jti)

      assert TokenRevocation.revoked?(jti)
    end

    test "returns false for nil" do
      refute TokenRevocation.revoked?(nil)
    end
  end

  describe "cleanup_expired/0" do
    test "removes expired entries" do
      # Create an entry that's already expired (exp in the past)
      expired_jti = "expired_#{System.unique_integer()}"
      # 1 hour ago
      past_exp = System.system_time(:second) - 3600

      TokenRevocation.revoke_by_jti(expired_jti, past_exp)

      # Verify it's there
      assert TokenRevocation.revoked?(expired_jti)

      # Cleanup
      count = TokenRevocation.cleanup_expired()

      # Should have cleaned up at least our expired entry
      assert count >= 1

      # The expired JTI should be gone
      refute TokenRevocation.revoked?(expired_jti)
    end

    test "keeps non-expired entries" do
      # Create an entry that expires in the future
      valid_jti = "valid_#{System.unique_integer()}"
      # 1 hour from now
      future_exp = System.system_time(:second) + 3600

      TokenRevocation.revoke_by_jti(valid_jti, future_exp)

      # Cleanup
      TokenRevocation.cleanup_expired()

      # The valid JTI should still be there
      assert TokenRevocation.revoked?(valid_jti)
    end
  end

  describe "get_stats/0" do
    test "returns stats about the revocation table" do
      stats = TokenRevocation.get_stats()

      assert is_integer(stats.count)
      assert is_integer(stats.memory_bytes)
      assert stats.count >= 0
      assert stats.memory_bytes >= 0
    end
  end

  describe "running?/0" do
    test "returns true when GenServer is running" do
      assert TokenRevocation.running?()
    end
  end

  describe "integration with Auth module" do
    test "logout revokes the token" do
      username = "logout_integration_#{System.unique_integer()}"
      {:ok, _user} = Grapple.Auth.register(username, "password", [:read_only])
      {:ok, token, claims} = Grapple.Auth.login(username, "password")

      jti = claims["jti"]

      # Token should be valid before logout
      assert {:ok, _user} = Grapple.Auth.validate_token(token)
      refute TokenRevocation.revoked?(jti)

      # Logout
      assert {:ok, :revoked} = Grapple.Auth.logout(token)

      # Token should be revoked after logout
      assert TokenRevocation.revoked?(jti)
    end

    test "revoked token fails validation" do
      username = "validation_integration_#{System.unique_integer()}"
      {:ok, _user} = Grapple.Auth.register(username, "password", [:read_only])
      {:ok, token, _claims} = Grapple.Auth.login(username, "password")

      # Valid before logout
      assert {:ok, _user} = Grapple.Auth.validate_token(token)

      # Logout
      {:ok, :revoked} = Grapple.Auth.logout(token)

      # Invalid after logout
      assert {:error, :token_revoked} = Grapple.Auth.validate_token(token)
    end
  end

  describe "JTI in tokens" do
    test "tokens include JTI claim" do
      username = "jti_test_#{System.unique_integer()}"
      {:ok, _user} = Grapple.Auth.register(username, "password", [:read_only])
      {:ok, _token, claims} = Grapple.Auth.login(username, "password")

      assert Map.has_key?(claims, "jti")
      assert is_binary(claims["jti"])
      assert String.length(claims["jti"]) > 0
    end

    test "each token gets a unique JTI" do
      username = "unique_jti_test_#{System.unique_integer()}"
      {:ok, _user} = Grapple.Auth.register(username, "password", [:read_only])

      {:ok, _token1, claims1} = Grapple.Auth.login(username, "password")
      {:ok, _token2, claims2} = Grapple.Auth.login(username, "password")

      refute claims1["jti"] == claims2["jti"]
    end
  end
end
