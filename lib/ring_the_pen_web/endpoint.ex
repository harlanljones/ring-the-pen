defmodule RingThePenWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ring_the_pen

  @session_options [
    store: :cookie,
    key: "_ring_the_pen_key",
    signing_salt: "rtp-session",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :ring_the_pen,
    gzip: not code_reloading?,
    only: RingThePenWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug RingThePenWeb.Router
end
