defmodule HeidyApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :heidy_api,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {HeidyApi.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp releases do
    [
      heidy_api: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.7.21"},
      {:postgrex, "~> 0.20"},
      {:plug_cowboy, "~> 2.7"},
      {:req, "~> 0.5"}
    ]
  end
end
