defmodule HeidyApi.Usp do
  @moduledoc """
  The USP integration boundary. Everything that knows USP exists lives
  under this namespace; the rest of the application only sees
  `HeidyApi.Usp.Client` results already translated into domain shapes.
  """

  @doc "The configured `HeidyApi.Usp.Client` implementation."
  @spec client() :: module()
  def client, do: Application.fetch_env!(:heidy_api, :usp_client)
end
