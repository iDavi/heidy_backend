defmodule HeidyApi.Release do
  @moduledoc false

  @app :heidy_api

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _started} = repo.start_link(pool_size: 2)
      Ecto.Migrator.run(repo, :up, all: true)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _started} = repo.start_link(pool_size: 2)
    Ecto.Migrator.run(repo, :down, to: version)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
