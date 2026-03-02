defmodule Elixir4absValidatorsWeb do
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {Elixir4absValidatorsWeb.Layouts, :app}
      unquote(verified_routes())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller, only: [get_csrf_token: 0]
      unquote(verified_routes())
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Elixir4absValidatorsWeb.Endpoint,
        router: Elixir4absValidatorsWeb.Router,
        statics: Elixir4absValidatorsWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
