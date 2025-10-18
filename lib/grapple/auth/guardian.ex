defmodule Grapple.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management in Grapple.
  """

  use Guardian, otp_app: :grapple

  alias Grapple.Auth.User

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
  Retrieves the user from the JWT subject claim.
  """
  def resource_from_claims(%{"sub" => user_id}) do
    User.find_by_id(user_id)
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
end
