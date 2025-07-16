defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.GPTClient
  alias NimbleCSV.RFC4180, as: CSV
  alias VegaLite, as: Vl

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, prompt: "", chart_svg: nil, loading: false)}
  end

  @impl true
  def handle_event("generate", %{"prompt" => prompt}, socket) do
    send(self(), {:generate_chart, prompt})
    {:noreply, assign(socket, prompt: prompt, loading: true, chart_svg: nil)}
  end

  @impl true
  def handle_info({:generate_chart, prompt}, socket) do
    case GPTClient.get_chart_spec(prompt) do
      {:ok, %{"charts" => [chart | _]}} ->
        with {:ok, rows} <- load_csv(chart["data_source"]),
             {:ok, vl} <- build_vega_spec(rows, chart),
             {:ok, svg} <- Vl.to_svg(vl) do
          {:noreply, assign(socket, chart_svg: svg, loading: false)}
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

  defp load_csv(filename) do
    path = Path.join(:code.priv_dir(:dashboard_gen), "static/data/" <> filename)

    if File.exists?(path) do
      rows =
        path
        |> File.stream!()
        |> CSV.parse_stream()
        |> Enum.to_list()

      case rows do
        [] ->
          {:ok, []}

        [headers | data_rows] ->
          headers = Enum.map(headers, &String.trim/1)

          data =
            Enum.map(data_rows, fn row ->
              headers
              |> Enum.zip(row)
              |> Map.new()
            end)

          {:ok, data}
      end
    else
      {:error, "CSV file not found: #{filename}"}
    end
  end

  defp build_vega_spec(rows, %{"type" => type, "x" => x_field, "y" => y_fields} = chart) do
    parsed =
      Enum.map(rows, fn row ->
        Enum.map([x_field | y_fields], fn field ->
          {field, parse_number(Map.get(row, field))}
        end)
        |> Map.new()
      end)

    spec =
      if length(y_fields) > 1 do
        melted =
          Enum.flat_map(parsed, fn row ->
            Enum.map(y_fields, fn field ->
              %{
                x_field => Map.get(row, x_field),
                "value" => Map.get(row, field),
                "color" => field
              }
            end)
          end)

        Vl.new(title: chart["title"])
        |> Vl.data_from_values(melted)
        |> Vl.mark(String.to_atom(type))
        |> Vl.encode_field(:x, x_field, type: :nominal)
        |> Vl.encode_field(:y, "value", type: :quantitative)
        |> Vl.encode_field(:color, "color", type: :nominal)
      else
        [y_field] = y_fields

        Vl.new(title: chart["title"])
        |> Vl.data_from_values(parsed)
        |> Vl.mark(String.to_atom(type))
        |> Vl.encode_field(:x, x_field, type: :nominal)
        |> Vl.encode_field(:y, y_field, type: :quantitative)
      end

    {:ok, spec}
  end

  defp parse_number(nil), do: nil

  defp parse_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> val
    end
  end

  defp parse_number(val), do: val
end
