defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.GPTClient
  alias DashboardGen.CSVUtils
  alias VegaLite

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, prompt: "", chart_spec: nil, loading: false)}
  end

  @impl true
  def handle_event("generate", %{"prompt" => prompt}, socket) do
    send(self(), {:generate_chart, prompt})
    {:noreply, assign(socket, prompt: prompt, loading: true, chart_spec: nil)}
  end

  @impl true
  def handle_info({:generate_chart, prompt}, socket) do
    case GPTClient.get_chart_spec(prompt) do
      {:ok, %{"charts" => [chart_spec | _]}} ->
        csv_path =
          Path.join(:code.priv_dir(:dashboard_gen), "static/data/" <> chart_spec["data_source"])

        data = CSVUtils.melt_wide_to_long(csv_path, chart_spec["x"], chart_spec["y"])

        vl =
          VegaLite.new()
          |> VegaLite.data_from_values(data)
          |> VegaLite.mark(String.to_atom(chart_spec["type"]))
          |> VegaLite.encode(:x, "x", type: :nominal)
          |> VegaLite.encode(:y, "value", type: :quantitative)
          |> VegaLite.encode(:color, "category", type: :nominal)
          |> VegaLite.title(chart_spec["title"])

        spec = VegaLite.to_spec(vl) |> Jason.encode!()

        {:noreply, assign(socket, chart_spec: spec, loading: false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(loading: false)}
    end
  end
end
