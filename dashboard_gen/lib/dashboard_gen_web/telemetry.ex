defmodule DashboardGenWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children =
      []
      |> maybe_add_poller()
      |> List.insert_at(-1, {Telemetry.Metrics.ConsoleReporter, metrics: metrics()})

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_add_poller(children) do
    if Code.ensure_loaded?(Telemetry.Poller) do
      [{Telemetry.Poller, measurements: periodic_measurements(), period: 10_000} | children]
    else
      children
    end
  end

  def metrics do
    [
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.mount.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.live_view.handle_event.stop.duration", unit: {:native, :millisecond})
    ]
  end

  defp periodic_measurements do
    []
  end
end
