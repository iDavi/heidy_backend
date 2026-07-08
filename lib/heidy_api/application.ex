defmodule HeidyApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HeidyApi.Store,
      {Task.Supervisor, name: HeidyApi.Usp.Sync.TaskSupervisor},
      HeidyApiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: HeidyApi.Supervisor)
  end
end
