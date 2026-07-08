defmodule HeidyApiWeb.Controllers.Helpers do
  @moduledoc false

  @spec current_user(Plug.Conn.t()) :: HeidyApi.Accounts.User.t()
  def current_user(conn), do: conn.assigns.current_user
end
