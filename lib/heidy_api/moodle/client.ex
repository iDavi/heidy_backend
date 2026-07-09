defmodule HeidyApi.Moodle.Client do
  @moduledoc "Behaviour for clients that read a student's e-Disciplinas calendar."

  alias HeidyApi.Moodle.{Assignment, Session}

  @type error :: :invalid_credentials | :unavailable

  @callback login(username :: String.t(), password :: String.t()) ::
              {:ok, Session.t()} | {:error, error()}

  @callback fetch_assignments(Session.t()) :: {:ok, [Assignment.t()]} | {:error, error()}
end
