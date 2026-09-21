import Config

config :ring_the_pen, RingThePenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: ["http://localhost:4000", "http://127.0.0.1:4000"],
  code_reloader: true,
  debug_errors: true,
  secret_key_base: String.duplicate("development-only-", 4),
  watchers: [esbuild: {Esbuild, :install_and_run, [:ring_the_pen, ~w(--watch)]}]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
