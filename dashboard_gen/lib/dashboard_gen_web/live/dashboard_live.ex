defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.GPTClient
  alias DashboardGen.Uploads
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
        with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
             {:ok, long_data} <- prepare_long_data(upload, chart_spec) do

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

  defp prepare_long_data(upload, %{"x" => x, "y" => y_fields}) do
    x_field = Uploads.normalize_header(x)
    y_fields = Enum.map(y_fields, &Uploads.normalize_header/1)

    if Enum.empty?(upload.data) do
      {:error, "No data available"}
    else
      long_data =
        Enum.flat_map(upload.data, fn row ->
          Enum.map(y_fields, fn y_field ->
            %{
              "x" => Map.get(row, x_field),
              "value" => Map.get(row, y_field),
              "category" => upload.headers[y_field] || y_field
            }
          end)
        end)

      {:ok, long_data}
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
