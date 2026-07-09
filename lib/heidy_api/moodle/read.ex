defmodule HeidyApi.Moodle.Read do
  @moduledoc """
  Read-only e-Disciplinas access for an authenticated heidy account.

  Credential blobs are opened for every request so revocation applies
  immediately. The Moodle browser session itself stays only in memory for a
  short period, avoiding a fresh SSO exchange for every course click.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Credentials
  alias HeidyApi.Moodle
  alias HeidyApi.Moodle.SessionCache

  @type error :: {:forbidden, String.t()} | :moodle_unavailable

  @spec courses(User.t(), String.t(), binary()) :: {:ok, [Moodle.Course.t()]} | {:error, error()}
  def courses(%User{} = user, credential_blob, cache_key) do
    with_session(user, credential_blob, cache_key, &Moodle.client().fetch_courses/1)
  end

  @spec course(User.t(), String.t(), pos_integer(), binary()) ::
          {:ok, Moodle.CourseDetail.t()} | {:error, error()}
  def course(%User{} = user, credential_blob, course_id, cache_key) do
    with_session(user, credential_blob, cache_key, &Moodle.client().fetch_course(&1, course_id))
  end

  @spec activity(User.t(), String.t(), String.t(), binary()) ::
          {:ok, Moodle.ActivityDetail.t()} | {:error, error()}
  def activity(%User{} = user, credential_blob, activity_url, cache_key) do
    with_session(
      user,
      credential_blob,
      cache_key,
      &Moodle.client().fetch_activity(&1, activity_url)
    )
  end

  defp with_session(user, credential_blob, cache_key, fetch) do
    with {:ok, password} <- open_blob(user, credential_blob) do
      case SessionCache.fetch(cache_key) do
        {:ok, session} ->
          fetch_with_refresh(cache_key, user, password, session, fetch)

        :miss ->
          with {:ok, session} <- Moodle.client().login(user.usp_username, password),
               :ok <- SessionCache.put(cache_key, session),
               {:ok, result} <- fetch.(session) do
            {:ok, result}
          else
            {:error, reason} -> normalize_error(reason)
          end
      end
    else
      {:error, reason} -> normalize_error(reason)
    end
  end

  defp fetch_with_refresh(cache_key, user, password, session, fetch) do
    case fetch.(session) do
      {:ok, result} ->
        {:ok, result}

      {:error, :unavailable} ->
        SessionCache.delete(cache_key)

        with {:ok, fresh_session} <- Moodle.client().login(user.usp_username, password),
             :ok <- SessionCache.put(cache_key, fresh_session),
             {:ok, result} <- fetch.(fresh_session) do
          {:ok, result}
        else
          {:error, reason} -> normalize_error(reason)
        end

      {:error, reason} ->
        normalize_error(reason)
    end
  end

  defp normalize_error(:invalid_credentials),
    do: {:error, {:forbidden, "Moodle did not accept this credential"}}

  defp normalize_error(:unavailable), do: {:error, :moodle_unavailable}
  defp normalize_error({:forbidden, _detail} = error), do: {:error, error}
  defp normalize_error(_reason), do: {:error, :moodle_unavailable}

  defp open_blob(user, blob) do
    case Credentials.open_blob(user, blob) do
      {:ok, password} -> {:ok, password}
      {:error, :expired} -> {:error, {:forbidden, "Credential blob is expired - log in again"}}
      {:error, :invalid} -> {:error, {:forbidden, "Credential blob is revoked or invalid"}}
    end
  end
end
