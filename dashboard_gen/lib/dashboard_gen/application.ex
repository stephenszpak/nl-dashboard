defmodule DashboardGen.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      DashboardGenWeb.Telemetry,
      DashboardGen.Repo,
      {Phoenix.PubSub, name: DashboardGen.PubSub},
      DashboardGenWeb.Endpoint,
      DashboardGen.Scheduler
    ]

    opts = [strategy: :one_for_one, name: DashboardGen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DashboardGenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
