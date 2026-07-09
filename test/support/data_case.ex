defmodule HeidyApi.DataCase do
  @moduledoc """
  Shared setup for tests that exercise Repo-backed application layers.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto.Query
      import HeidyApi.DataCase
      import HeidyApi.Fixtures

      alias HeidyApi.Repo
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(HeidyApi.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(HeidyApi.Repo, {:shared, self()})
    end

    :ok
  end

  def validation_errors({:error, {:validation, fields}}), do: fields
end
