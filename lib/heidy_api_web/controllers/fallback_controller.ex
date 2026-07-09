defmodule HeidyApiWeb.FallbackController do
  @moduledoc """
  Translates context error tuples into the API's single error envelope:
  `{"errors": {"detail": "...", "fields": {...}}}` with an honest status.
  """

  use Phoenix.Controller, formats: []

  def call(conn, {:error, {:validation, fields}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Validation failed", fields: fields}})
  end

  def call(conn, {:error, :not_found}) do
    error(conn, :not_found, "Not found")
  end

  def call(conn, {:error, :unauthorized}) do
    error(conn, :unauthorized, "USP did not accept these credentials")
  end

  def call(conn, {:error, {:forbidden, detail}}) do
    error(conn, :forbidden, detail)
  end

  def call(conn, {:error, {:conflict, detail}}) do
    error(conn, :conflict, detail)
  end

  def call(conn, {:error, :usp_unavailable}) do
    error(conn, :service_unavailable, "USP is unreachable right now — try again later")
  end

  def call(conn, {:error, :moodle_unavailable}) do
    error(conn, :service_unavailable, "Moodle is unreachable right now — try again later")
  end

  defp error(conn, status, detail) do
    conn |> put_status(status) |> json(%{errors: %{detail: detail}})
  end
end
