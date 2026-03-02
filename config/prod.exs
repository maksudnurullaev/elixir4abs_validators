import Config

config :elixir4abs_validators, Elixir4absValidatorsWeb.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
