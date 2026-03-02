defmodule Elixir4absValidatorsWeb.Router do
  use Elixir4absValidatorsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Elixir4absValidatorsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Elixir4absValidatorsWeb do
    pipe_through :browser

    live "/", AccountValidatorLive
  end
end
