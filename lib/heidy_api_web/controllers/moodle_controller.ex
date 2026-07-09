defmodule HeidyApiWeb.MoodleController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Moodle.Read

  @credential_schema [credential_blob: [type: :string, required: true]]

  def courses(conn, params) do
    with {:ok, %{credential_blob: blob}} <- Params.validate(params, @credential_schema),
         {:ok, courses} <- Read.courses(current_user(conn), blob, cache_key(conn)) do
      data(conn, courses)
    end
  end

  def course(conn, %{"id" => id} = params) do
    with {:ok, %{credential_blob: blob}} <- Params.validate(params, @credential_schema),
         {:ok, course_id} <- parse_id(id),
         {:ok, course} <- Read.course(current_user(conn), blob, course_id, cache_key(conn)) do
      data(conn, course)
    end
  end

  def activity(conn, params) do
    schema = @credential_schema ++ [url: [type: :string, required: true, max: 2_000]]

    with {:ok, %{credential_blob: blob, url: url}} <- Params.validate(params, schema),
         {:ok, activity} <- Read.activity(current_user(conn), blob, url, cache_key(conn)) do
      data(conn, activity)
    end
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {course_id, ""} when course_id > 0 -> {:ok, course_id}
      _invalid -> {:error, :not_found}
    end
  end

  defp cache_key(conn) do
    conn.assigns.current_token
    |> then(&:crypto.hash(:sha256, &1))
  end
end
