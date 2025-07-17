defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.GPTClient
  alias DashboardGen.CSVUtils
  alias DashboardGen.CSVHeaderMapper
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
          Path.join(:code.priv_dir(:dashboard_gen), "static/data/mock_marketing_data.csv")

        x_field = CSVHeaderMapper.normalize_field(chart_spec["x"])
        y_fields = Enum.map(chart_spec["y"], &CSVHeaderMapper.normalize_field/1)

        with {:ok, raw_data} <- CSVUtils.melt_wide_to_long(csv_path, x_field, y_fields) do
          IO.inspect(raw_data, label: "Raw Data from CSV")
          long_data =
            Enum.map(raw_data, fn %{x: x, value: value, category: category} ->
              %{"x" => x, "value" => value, "category" => category}
            end)

          vl =
            VegaLite.new(%{"title" => chart_spec["title"]})
            |> VegaLite.data_from_values(long_data)
            |> VegaLite.mark(String.to_atom(chart_spec["type"]))
            |> VegaLite.encode(:x, field: "x", type: :nominal)
            |> VegaLite.encode(:y, field: "value", type: :quantitative)
            |> VegaLite.encode(:color, field: "category", type: :nominal)

          spec = VegaLite.to_spec(vl) |> Jason.encode!()

          {:noreply, assign(socket, chart_spec: spec, loading: false)}
        else
          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, reason)
             |> assign(loading: false)}
        end

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

    VegaLite.new(%{"title" => "Ad Spend and Conversions by Month"})
    |> VegaLite.data_from_values(long_data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode(:x, field: "x", type: :nominal)
    |> VegaLite.encode(:y, field: "value", type: :quantitative)
    |> VegaLite.encode(:color, field: "category", type: :nominal)
  end
end
