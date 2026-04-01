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

    live "/",                   HomeLive
    live "/validators/account",       AccountValidatorLive
    live "/validators/swift-pacs008", SwiftPacs008Live
    live "/validators/qr-payment",    QrPaymentLive

    live "/rules",          RulesIndexLive
    live "/rules/:ruleset", RulesViewerLive

    live "/*path", NotFoundLive
  end
end
