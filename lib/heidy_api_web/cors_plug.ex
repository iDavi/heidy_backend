defmodule HeidyApiWeb.CorsPlug do
  @moduledoc "CORS handling for browser frontends."

  import Plug.Conn

  @allowed_methods "GET, POST, PATCH, DELETE, OPTIONS"
  @allowed_headers "authorization, content-type, accept"
  @max_age "86400"

  @spec init(term()) :: term()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> put_cors_headers()
    |> maybe_answer_preflight()
  end

  defp put_cors_headers(conn) do
    origin = conn |> get_req_header("origin") |> List.first()

    case allowed_origin(origin) do
      nil ->
        conn

      "*" ->
        conn
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_common_headers()

      allowed ->
        conn
        |> put_resp_header("access-control-allow-origin", allowed)
        |> put_resp_header("vary", "origin")
        |> put_common_headers()
    end
  end

  defp put_common_headers(conn) do
    conn
    |> put_resp_header("access-control-allow-methods", @allowed_methods)
    |> put_resp_header("access-control-allow-headers", @allowed_headers)
    |> put_resp_header("access-control-max-age", @max_age)
  end

  defp maybe_answer_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> send_resp(:no_content, "")
    |> halt()
  end

  defp maybe_answer_preflight(conn), do: conn

  defp allowed_origin(nil), do: nil

  defp allowed_origin(origin) do
    allowed = Application.get_env(:heidy_api, :cors_allowed_origins, [])

    cond do
      "*" in allowed -> "*"
      origin in allowed -> origin
      true -> nil
    end
  end
end
