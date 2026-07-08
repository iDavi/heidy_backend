defmodule HeidyApiWeb.Auth do
  @moduledoc "Resolves the bearer token to `conn.assigns.current_user` or halts with 401."

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias HeidyApi.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.fetch_user_by_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_token, token)
    else
      _missing_or_invalid ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Missing or invalid bearer token"}})
        |> halt()
    end
  end
end
