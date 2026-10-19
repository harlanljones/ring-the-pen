defmodule RingThePenWeb.Router do
  use RingThePenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RingThePenWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", RingThePenWeb do
    pipe_through :browser

    live "/", WorkbenchLive
    live "/cards/:id", WorkbenchLive
    live "/about", AboutLive
  end
end
