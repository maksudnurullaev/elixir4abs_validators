defmodule Elixir4absValidatorsWeb.NotFoundLive do
  use Elixir4absValidatorsWeb, :live_view

  @impl true
  def mount(%{"path" => path}, _session, socket) do
    url = "/" <> Enum.join(path, "/")

    {:ok,
     socket
     |> put_flash(:error, "Страница «#{url}» не найдена. Перенаправляем на главную.")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def render(assigns), do: ~H""
end
