defmodule HeidyApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :heidy_api,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support"]
  defp elixirc_paths(_), do: []

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.7.21", only: :test},
      {:plug_cowboy, "~> 2.7", only: :test}
    ]
  end
end
