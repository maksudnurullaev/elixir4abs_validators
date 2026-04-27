defmodule Elixir4absValidatorsWeb.AuthController do
  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  def new(conn, _params) do
    render(conn, :new, error: false)
  end

  def create(conn, %{"password" => password}) do
    today = Date.utc_today() |> Calendar.strftime("%Y%m%d")

    if password == today do
      return_to = get_session(conn, :return_to) || "/"

      conn
      |> delete_session(:return_to)
      |> put_session(:authenticated, true)
      |> redirect(to: return_to)
    else
      render(conn, :new, error: true)
    end
  end
end
