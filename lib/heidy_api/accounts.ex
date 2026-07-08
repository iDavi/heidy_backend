defmodule HeidyApi.Accounts do
  @moduledoc """
  heidy identity. There is no register/password surface: `login/2` verifies
  the credential against USP live and creates the account on first success.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Credentials
  alias HeidyApi.Credentials.Blob
  alias HeidyApi.{Demo, Ids, Store, Usp}

  @type session :: %{user: User.t(), token: String.t(), credential_blob: Blob.t()}

  @doc """
  Verifies a login envelope against USP and opens a session.

  The decrypted password lives only on this call's stack: it is replayed
  against USP, sealed into the credential blob, and dropped.
  """
  @spec login(String.t(), Credentials.Vault.envelope()) ::
          {:ok, session()} | {:error, :unauthorized | :usp_unavailable}
  def login(usp_username, envelope) do
    with {:ok, password} <- open_envelope(envelope),
         {:ok, usp_session} <- Usp.client().login(usp_username, password),
         {:ok, student} <- Usp.client().fetch_student(usp_session) do
      user = upsert_user(usp_username, student.name)
      {:ok, blob} = Credentials.issue_blob(user, password)
      {:ok, %{user: user, token: issue_token(user), credential_blob: blob}}
    else
      {:error, :invalid_envelope} -> {:error, :unauthorized}
      {:error, :invalid_credentials} -> {:error, :unauthorized}
      {:error, :unavailable} -> {:error, :usp_unavailable}
    end
  end

  @doc "Resolves a bearer token to its user."
  @spec fetch_user_by_token(String.t()) :: {:ok, User.t()} | {:error, :unauthorized}
  def fetch_user_by_token(token) do
    case Store.get(:sessions, token) || demo_session(token) do
      nil -> {:error, :unauthorized}
      user_id -> {:ok, current_user(user_id)}
    end
  end

  @doc "Revokes the given session token."
  @spec logout(String.t()) :: :ok
  def logout(token), do: Store.delete(:sessions, token)

  @doc "Updates the user's own profile fields."
  @spec update_profile(User.t(), map()) :: {:ok, User.t()}
  def update_profile(%User{} = user, attrs) do
    {:ok, Store.put(:users, struct!(user, attrs))}
  end

  @doc "Deletes the account and revokes its credentials."
  @spec delete_account(User.t()) :: :ok
  def delete_account(%User{} = user) do
    Credentials.revoke(user)
    Store.delete(:users, user.id)
  end

  defp open_envelope(envelope) do
    case Credentials.open_envelope(envelope) do
      {:ok, password} -> {:ok, password}
      {:error, :invalid_envelope} -> {:error, :invalid_envelope}
    end
  end

  defp upsert_user(usp_username, name) do
    existing = Enum.find(Store.list(:users), &(&1.usp_username == usp_username))

    user =
      case existing do
        nil -> %User{id: Ids.generate(), usp_username: usp_username, name: name}
        %User{} = user -> %{user | name: user.name || name}
      end

    Store.put(:users, user)
  end

  defp issue_token(%User{id: user_id}) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    Store.put(:sessions, token, user_id)
    token
  end

  # Until database-backed sessions land, a configured fixed token (used by
  # the contract suite and for local curl sessions) maps to the demo user.
  defp demo_session(token) do
    if token != "" and token == Application.get_env(:heidy_api, :demo_session_token) do
      Demo.user().id
    end
  end

  defp current_user(user_id) do
    Store.get(:users, user_id) || %{Demo.user() | id: user_id}
  end
end
