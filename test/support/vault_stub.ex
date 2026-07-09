defmodule HeidyApi.VaultStub do
  @moduledoc """
  A `HeidyApi.Credentials.Vault` for the contract suite: no cryptography,
  deterministic outputs, and a recognizable "expired-or-revoked" blob to
  exercise the forbidden path.
  """

  @behaviour HeidyApi.Credentials.Vault

  alias HeidyApi.Credentials.{Blob, LoginKey}

  @impl true
  def login_key do
    %LoginKey{
      key_id: "stub-key-1",
      alg: "HPKE-Base(X25519, HKDF-SHA256, AES-256-GCM)",
      public_key: Base.encode64("stub-public-key")
    }
  end

  @impl true
  def open_envelope(_envelope), do: {:ok, "stub-password"}

  @impl true
  def seal(_user_key, _context, _secret) do
    {:ok, %Blob{blob: "stub-blob", expires_at: DateTime.add(DateTime.utc_now(:second), 90, :day)}}
  end

  @impl true
  def unseal(_user_key, _context, "expired-or-revoked"), do: {:error, :expired}
  def unseal(_user_key, _context, _blob), do: {:ok, "stub-password"}
end
