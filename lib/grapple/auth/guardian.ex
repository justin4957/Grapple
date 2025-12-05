defmodule Grapple.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management in Grapple.

  This module handles:
  - Token encoding/decoding with unique JTI (JWT ID) for each token
  - Token revocation checking during validation
  - User resource retrieval from claims
  """

  use Guardian, otp_app: :grapple

  alias Grapple.Auth.{User, TokenRevocation}

  @doc """
  Encodes the user's ID into the JWT subject claim.
  """
  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :invalid_resource}
  end

  @doc """
  Adds a unique JTI (JWT ID) to each token for revocation tracking.

  Called automatically by Guardian when encoding tokens.
  """
  def build_claims(claims, _resource, _opts) do
    jti = generate_jti()
    {:ok, Map.put(claims, "jti", jti)}
  end

  @doc """
  Retrieves the user from the JWT claims.

  Checks if the token has been revoked before returning the user.
  Returns `{:error, :token_revoked}` if the token's JTI is in the revocation list.
  """
  def resource_from_claims(%{"sub" => user_id, "jti" => jti}) when is_binary(jti) do
    if TokenRevocation.running?() and TokenRevocation.revoked?(jti) do
      {:error, :token_revoked}
    else
      User.find_by_id(user_id)
    end
  end

  def resource_from_claims(%{"sub" => user_id}) do
    # Legacy tokens without JTI - allow for backward compatibility
    User.find_by_id(user_id)
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end

  # Private Functions

  defp generate_jti do
    # Generate a unique identifier for the token
    # Using timestamp + random bytes for uniqueness
    timestamp = System.system_time(:microsecond)
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    "#{timestamp}_#{random}"
  end
end
