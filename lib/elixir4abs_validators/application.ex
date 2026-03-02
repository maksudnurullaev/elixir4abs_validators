defmodule Elixir4absValidators.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Elixir4absValidators.PubSub},
      Elixir4absValidatorsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Elixir4absValidators.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Elixir4absValidatorsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
