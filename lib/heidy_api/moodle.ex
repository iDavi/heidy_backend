defmodule HeidyApi.Moodle do
  @moduledoc """
  The e-Disciplinas integration boundary.

  Moodle is a separate USP service, even though it uses the same Senha Unica.
  Callers receive normalized calendar assignments and never handle its SAML or
  HTML details directly.
  """

  @doc "The configured e-Disciplinas client."
  @spec client() :: module()
  def client, do: Application.fetch_env!(:heidy_api, :moodle_client)
end
