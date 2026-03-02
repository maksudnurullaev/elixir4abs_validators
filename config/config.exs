import Config

config :elixir4abs_validators, Elixir4absValidatorsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Elixir4absValidatorsWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Elixir4absValidators.PubSub,
  live_view: [signing_salt: "Hx9kRmLp"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.17.11",
  elixir4abs_validators: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  elixir4abs_validators: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
