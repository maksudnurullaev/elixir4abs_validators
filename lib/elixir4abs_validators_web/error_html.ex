defmodule Elixir4absValidatorsWeb.ErrorHTML do
  use Elixir4absValidatorsWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
