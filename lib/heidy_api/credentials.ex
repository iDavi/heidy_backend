defmodule HeidyApi.Credentials do
  @moduledoc """
  Issues, opens and revokes credential blobs. Stores *keys about* the
  credential — never the credential: the USP password only ever exists in
  worker memory, inside `HeidyApi.Credentials.Vault` calls.

  Each user has one vault key (`K_user`). Rotating it — `revoke/1` — makes
  every blob ever issued to that user unopenable, which is the remote kill
  switch behind `DELETE /me/credential`.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Credentials.{Blob, LoginKey, Vault}
  alias HeidyApi.Store

  @doc "The public key clients seal login credentials to."
  @spec login_key() :: LoginKey.t()
  def login_key, do: vault().login_key()

  @doc "Opens the login envelope. The result must never be persisted or logged."
  @spec open_envelope(Vault.envelope()) :: {:ok, binary()} | {:error, :invalid_envelope}
  def open_envelope(envelope), do: vault().open_envelope(envelope)

  @doc "Seals `secret` into a fresh blob for `user`."
  @spec issue_blob(User.t(), binary()) :: {:ok, Blob.t()}
  def issue_blob(%User{} = user, secret) do
    {key, version} = user_key(user)
    vault().seal(key, %{user_id: user.id, key_version: version}, secret)
  end

  @doc "Opens a blob previously issued to `user`."
  @spec open_blob(User.t(), String.t()) :: {:ok, binary()} | {:error, :invalid | :expired}
  def open_blob(%User{} = user, blob) do
    {key, version} = user_key(user)
    vault().unseal(key, %{user_id: user.id, key_version: version}, blob)
  end

  @doc "Rotates the user's vault key, revoking every outstanding blob."
  @spec revoke(User.t()) :: :ok
  def revoke(%User{} = user) do
    {_key, version} = user_key(user)
    Store.put(:credential_keys, user.id, {new_key(), version + 1})
    :ok
  end

  defp user_key(user) do
    case Store.get(:credential_keys, user.id) do
      nil -> Store.put(:credential_keys, user.id, {new_key(), 1})
      {key, version} -> {key, version}
    end
  end

  defp new_key, do: :crypto.strong_rand_bytes(32)

  defp vault, do: Application.fetch_env!(:heidy_api, :vault)
end
