defmodule RingThePen.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: RingThePen.PubSub},
      RingThePenWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: RingThePen.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RingThePenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
