defmodule Elixir4absValidators.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir4abs_validators,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Elixir4absValidators.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind elixir4abs_validators", "esbuild elixir4abs_validators"],
      "assets.deploy": [
        "tailwind elixir4abs_validators --minify",
        "esbuild elixir4abs_validators --minify",
        "phx.digest"
      ]
    ]
  end
end
