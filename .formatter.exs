[
  import_deps: [:phoenix, :phoenix_live_view],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{ex,exs}",
    "{config,test}/**/*.{ex,exs}",
    "lib/elixir4abs_validators_web.ex",
    "lib/elixir4abs/*.ex",
    "lib/elixir4abs/swift/**/*.{ex,exs}",
    "lib/elixir4abs_validators/**/*.{ex,exs}",
    "lib/elixir4abs_validators_web/**/*.{ex,exs}",
    "priv/*/seeds.exs"
  ]
]
