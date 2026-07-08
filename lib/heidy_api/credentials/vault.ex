defmodule HeidyApi.Credentials.Vault do
  @moduledoc """
  The cryptography boundary of `HeidyApi.Credentials`.

  Everything that touches key material or plaintext credentials sits behind
  this behaviour, so the rest of the application never sees a cipher: it
  hands the vault an envelope or a blob and gets a secret back (in memory,
  never persisted). Swapping the local implementation for a KMS/HSM-backed
  one is a config change.
  """

  alias HeidyApi.Credentials.{Blob, LoginKey}

  @typedoc "The HPKE envelope posted by the client at login."
  @type envelope :: %{
          key_id: String.t(),
          enc: String.t(),
          ciphertext: String.t(),
          encrypted_at: DateTime.t()
        }

  @typedoc "Binds a blob to one user and one key generation (the AEAD AAD)."
  @type context :: %{user_id: String.t(), key_version: pos_integer()}

  @doc "The current login public key advertised at `GET /auth/login-key`."
  @callback login_key() :: LoginKey.t()

  @doc "Opens a login envelope, returning the plaintext credential."
  @callback open_envelope(envelope()) :: {:ok, binary()} | {:error, :invalid_envelope}

  @doc "Seals a credential into a blob under the per-user vault key."
  @callback seal(user_key :: binary(), context(), secret :: binary()) :: {:ok, Blob.t()}

  @doc "Opens a blob issued by `seal/3`. Fails closed on any mismatch."
  @callback unseal(user_key :: binary(), context(), blob :: String.t()) ::
              {:ok, binary()} | {:error, :invalid | :expired}
end
