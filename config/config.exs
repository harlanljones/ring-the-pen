import Config

config :ring_the_pen, RingThePenWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: RingThePenWeb.ErrorHTML], layout: false],
  pubsub_server: RingThePen.PubSub,
  live_view: [signing_salt: "rtp-live-view"]

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.25.12",
  ring_the_pen: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
