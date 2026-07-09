defmodule HeidyApi.Accounts do
  @moduledoc """
  heidy identity. There is no register/password surface: `login/2` verifies
  the credential against USP live and creates the account on first success.
  """

  import Ecto.Query

  alias HeidyApi.Accounts.{Session, User}
  alias HeidyApi.Changeset
  alias HeidyApi.Credentials
  alias HeidyApi.Credentials.Blob
  alias HeidyApi.{Demo, Repo, Usp}

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
    case Repo.get_by(Session, token_hash: token_hash(token)) do
      %Session{user_id: user_id} -> fetch_user(user_id)
      nil -> demo_session(token)
    end
  end

  @doc "Revokes the given session token."
  @spec logout(String.t()) :: :ok
  def logout(token) do
    Repo.delete_all(from(session in Session, where: session.token_hash == ^token_hash(token)))
    :ok
  end

  @doc "Updates the user's own profile fields."
  @spec update_profile(User.t(), map()) :: {:ok, User.t()} | Changeset.validation_error()
  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
    |> normalize_changeset_error()
  end

  @doc "Deletes the account and revokes its credentials."
  @spec delete_account(User.t()) :: :ok
  def delete_account(%User{} = user) do
    Credentials.revoke(user)
    Repo.delete(user)
    :ok
  end

  defp open_envelope(envelope) do
    case Credentials.open_envelope(envelope) do
      {:ok, password} -> {:ok, password}
      {:error, :invalid_envelope} -> {:error, :invalid_envelope}
    end
  end

  defp upsert_user(usp_username, name) do
    case Repo.get_by(User, usp_username: usp_username) do
      nil ->
        %User{}
        |> User.changeset(%{usp_username: usp_username, name: name})
        |> Repo.insert!()

      %User{} = user ->
        user
        |> User.changeset(%{name: user.name || name})
        |> Repo.update!()
    end
  end

  defp issue_token(%User{id: user_id}) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    %Session{}
    |> Session.changeset(%{user_id: user_id, token_hash: token_hash(token)})
    |> Repo.insert!()

    token
  end

  # A configured fixed token maps to a persisted demo user for the contract
  # suite and local curl sessions. Real sessions are stored as token hashes.
  defp demo_session(token) do
    if token != "" and token == Application.get_env(:heidy_api, :demo_session_token) do
      {:ok, ensure_user(Demo.user())}
    else
      {:error, :unauthorized}
    end
  end

  defp fetch_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :unauthorized}
      %User{} = user -> {:ok, user}
    end
  end

  defp ensure_user(%User{} = user) do
    case Repo.get(User, user.id) do
      nil ->
        %User{}
        |> User.changeset(Map.take(user, [:id, :usp_username, :name, :email, :course_id]))
        |> Repo.insert!()

      %User{} = user ->
        user
    end
  end

  defp token_hash(token) do
    :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)
  end

  defp normalize_changeset_error({:ok, record}), do: {:ok, record}
  defp normalize_changeset_error({:error, changeset}), do: Changeset.validation_error(changeset)
end
