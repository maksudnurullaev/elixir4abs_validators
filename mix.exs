defmodule Elixir4absValidators.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir4abs_validators,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  # Configuration for the OTP application
  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
