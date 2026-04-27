defmodule Elixir4absValidatorsWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  def check(conn, _params) do
    json(conn, %{status: "ok-v2"})
  end
end
