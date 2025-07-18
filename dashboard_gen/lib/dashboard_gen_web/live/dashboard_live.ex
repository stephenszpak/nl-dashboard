defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  alias DashboardGen.GPTClient
  alias DashboardGen.Codex.Summarizer
  alias DashboardGen.Codex.Explainer
  alias DashboardGen.Uploads
  alias DashboardGen.AnomalyDetector
  alias VegaLite

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Dashboard",
       prompt: "",
       chart_spec: nil,
       loading: false,
       collapsed: false,
       summary: nil,
       explanation: nil,
       alerts: nil
     )}
  end

  @impl true
  def handle_event("generate", %{"prompt" => prompt}, socket) do
    send(self(), {:generate_chart, prompt})

    {:noreply,
     assign(socket,
       prompt: prompt,
       loading: true,
       chart_spec: nil,
       summary: nil,
       explanation: nil,
       alerts: nil
     )}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("generate_summary", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, summary} <-
           Summarizer.summarize(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, summary: summary)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  def handle_event("explain_this", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, explanation} <-
           Explainer.explain(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, explanation: explanation)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  def handle_event("why_this", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, explanation} <-
           Explainer.why(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, explanation: explanation)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  @impl true
  def handle_info({:generate_chart, prompt}, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, spec} <- GPTClient.get_chart_spec(prompt, upload.headers),
         %{"charts" => [chart_spec | _]} <- spec,
         {:ok, long_data} <- prepare_long_data(upload, chart_spec) do
      vl =
        VegaLite.new(%{"title" => chart_spec["title"]})
        |> VegaLite.data_from_values(long_data)
        |> VegaLite.mark(String.to_atom(chart_spec["type"]))
        |> VegaLite.encode(:x, field: "x", type: :nominal)
        |> VegaLite.encode(:y, field: "value", type: :quantitative)
        |> VegaLite.encode(:color, field: "category", type: :nominal)

      spec = VegaLite.to_spec(vl) |> Jason.encode!()

      alerts =
        with {:ok, anomalies} <- AnomalyDetector.detect_anomalies(upload.headers, upload.data),
             true <- anomalies != [],
             {:ok, summary} <- AnomalyDetector.summarize_anomalies(anomalies) do
          summary
        else
          {:ok, []} -> nil
          _ -> nil
        end

      {:noreply,
       assign(socket,
         chart_spec: spec,
         loading: false,
         summary: nil,
         explanation: nil,
         alerts: alerts
       )}
    else
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(loading: false, alerts: nil)}
    end
  end

  defp prepare_long_data(upload, chart_spec) do
    x_field = Uploads.resolve_field(chart_spec["x"], upload.headers)
    y_fields = Enum.map(chart_spec["y"] || [], &Uploads.resolve_field(&1, upload.headers))

    color_field =
      chart_spec["color"] ||
        chart_spec["group_by"]
        |> Uploads.resolve_field(upload.headers)

    unresolved =
      []
      |> maybe_add_unresolved(x_field, chart_spec["x"])
      |> maybe_add_unresolved_list(y_fields, chart_spec["y"] || [])
      |> maybe_add_unresolved(color_field, chart_spec["color"] || chart_spec["group_by"])

    cond do
      unresolved != [] ->
        {:error, "Could not resolve fields: #{Enum.join(unresolved, ", ")}"}

      Enum.empty?(upload.data) ->
        {:error, "No data available"}

      true ->
        long_data =
          Enum.flat_map(upload.data, fn row ->
            Enum.map(y_fields, fn y_field ->
              category =
                cond do
                  color_field -> Map.get(row, color_field)
                  true -> upload.headers[y_field] || y_field
                end

              %{
                "x" => Map.get(row, x_field),
                "value" => Map.get(row, y_field),
                "category" => category
              }
            end)
          end)

        {:ok, long_data}
    end
  end

  defp maybe_add_unresolved(list, nil, original) when is_binary(original), do: [original | list]
  defp maybe_add_unresolved(list, _resolved, _original), do: list

  defp maybe_add_unresolved_list(list, resolved_list, originals) do
    originals
    |> Enum.zip(resolved_list)
    |> Enum.reduce(list, fn
      {orig, nil}, acc -> [orig | acc]
      {_, _}, acc -> acc
    end)
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
