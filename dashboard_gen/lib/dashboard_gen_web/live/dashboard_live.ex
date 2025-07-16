defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.GPTClient
  alias NimbleCSV.RFC4180, as: CSV
  alias Contex.{Dataset, Plot, BarChart}

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
             {:ok, dataset} <- build_dataset(rows, chart["x"], chart["y"]),
             svg <- render_chart(dataset, chart) do
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

  defp build_dataset(rows, x_field, y_fields) do
    data =
      Enum.map(rows, fn row ->
        [Map.get(row, x_field) | Enum.map(y_fields, &parse_number(Map.get(row, &1)))]
      end)

    headers = [x_field | y_fields]
    {:ok, Dataset.new(data, headers)}
  end

  defp parse_number(nil), do: nil

  defp parse_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> val
    end
  end

  defp parse_number(val), do: val

  defp render_chart(dataset, %{"title" => title, "x" => x, "y" => y_fields}) do
    mapping = %{category_col: x, value_cols: y_fields}

    Plot.new(dataset, BarChart, mapping: mapping)
    |> Plot.titles(title, nil)
    |> Plot.to_svg()
  end
end
