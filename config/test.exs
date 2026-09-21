import Config

config :ring_the_pen, RingThePenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: String.duplicate("test-only-secret-", 4),
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
