defmodule HeidyApi.Moodle.Read do
  @moduledoc """
  Read-only e-Disciplinas access for an authenticated heidy account.

  Every request opens the device-held credential blob, creates one fresh Moodle
  session, fetches the requested page, and discards both the password and
  cookies before returning. Nothing from Moodle is writable through this API.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Credentials
  alias HeidyApi.Moodle

  @type error :: {:forbidden, String.t()} | :moodle_unavailable

  @spec courses(User.t(), String.t()) :: {:ok, [Moodle.Course.t()]} | {:error, error()}
  def courses(%User{} = user, credential_blob) do
    with_session(user, credential_blob, &Moodle.client().fetch_courses/1)
  end

  @spec course(User.t(), String.t(), pos_integer()) ::
          {:ok, Moodle.CourseDetail.t()} | {:error, error()}
  def course(%User{} = user, credential_blob, course_id) do
    with_session(user, credential_blob, &Moodle.client().fetch_course(&1, course_id))
  end

  @spec activity(User.t(), String.t(), String.t()) ::
          {:ok, Moodle.ActivityDetail.t()} | {:error, error()}
  def activity(%User{} = user, credential_blob, activity_url) do
    with_session(user, credential_blob, &Moodle.client().fetch_activity(&1, activity_url))
  end

  defp with_session(user, credential_blob, fetch) do
    with {:ok, password} <- open_blob(user, credential_blob),
         {:ok, session} <- Moodle.client().login(user.usp_username, password),
         {:ok, result} <- fetch.(session) do
      {:ok, result}
    else
      {:error, :invalid_credentials} ->
        {:error, {:forbidden, "Moodle did not accept this credential"}}

      {:error, :unavailable} ->
        {:error, :moodle_unavailable}

      {:error, _reason} = error ->
        error
    end
  end

  defp open_blob(user, blob) do
    case Credentials.open_blob(user, blob) do
      {:ok, password} -> {:ok, password}
      {:error, :expired} -> {:error, {:forbidden, "Credential blob is expired - log in again"}}
      {:error, :invalid} -> {:error, {:forbidden, "Credential blob is revoked or invalid"}}
    end
  end
end
