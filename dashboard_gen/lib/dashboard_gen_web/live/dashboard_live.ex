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
          |> VegaLite.encode(:x, field: "x", type: :nominal)
          |> VegaLite.encode(:y, field: "value", type: :quantitative)
          |> VegaLite.encode(:color, field: "category", type: :nominal)
          |> VegaLite.set_spec(["title"], chart_spec["title"])

        spec = VegaLite.to_spec(vl) |> Jason.encode!()

        {:noreply, assign(socket, chart_spec: spec, loading: false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(loading: false)}
    end
  end

  @doc """
  Build a sample VegaLite chart using inline mock data.
  """
  def sample_chart do
    data = [
      %{"Month" => "Jan", "Ad Spend" => 1000, "Conversions" => 50},
      %{"Month" => "Feb", "Ad Spend" => 1200, "Conversions" => 65},
      %{"Month" => "Mar", "Ad Spend" => 1500, "Conversions" => 80}
    ]

    long_data =
      Enum.flat_map(data, fn row ->
        ["Ad Spend", "Conversions"]
        |> Enum.map(fn category ->
          %{
            "x" => row["Month"],
            "category" => category,
            "value" => row[category]
          }
        end)
      end)

    VegaLite.new()
    |> VegaLite.data_from_values(long_data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode(:x, field: "x", type: :nominal)
    |> VegaLite.encode(:y, field: "value", type: :quantitative)
    |> VegaLite.encode(:color, field: "category", type: :nominal)
    |> VegaLite.set_spec(["title"], "Ad Spend and Conversions by Month")
  end
end
