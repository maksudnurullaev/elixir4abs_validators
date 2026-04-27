defmodule Elixir4absValidatorsWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :authenticated) do
      conn
    else
      conn
      |> put_session(:return_to, conn.request_path)
      |> redirect(to: "/lock")
      |> halt()
    end
  end
end
