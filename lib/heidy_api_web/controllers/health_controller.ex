defmodule HeidyApiWeb.HealthController do
  use HeidyApiWeb, :controller

  def show(conn, _params) do
    version = :heidy_api |> Application.spec(:vsn) |> to_string()
    json(conn, %{status: "ok", version: version})
  end
end
