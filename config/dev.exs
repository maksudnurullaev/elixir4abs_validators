import Config

port = String.to_integer(System.get_env("PORT") || "4000")

config :elixir4abs_validators, Elixir4absValidatorsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: port],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "localdevsecretkeybase64charsminimumrequiredforphoenix12345678901234",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:elixir4abs_validators, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:elixir4abs_validators, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/elixir4abs_validators_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, level: :debug
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, :debug_heex_annotations, true
