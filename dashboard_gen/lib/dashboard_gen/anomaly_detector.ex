defmodule DashboardGen.AnomalyDetector do
  @moduledoc """
  Simple detection of day-over-day spikes or drops in marketing metrics.
  """


  @metrics ["cost_per_click", "clicks", "conversions", "cpc"]

  @spec detect_anomalies(map(), list()) ::
          {:ok,
           [
             %{
               metric: String.t(),
               date: String.t(),
               percent_change: float(),
               direction: :up | :down,
               source: String.t()
             }
           ]}
  def detect_anomalies(headers, rows)
      when is_map(headers) and is_list(rows) do
    metrics =
      @metrics
      |> Enum.filter(fn m -> Map.has_key?(headers, m) || Enum.any?(rows, &Map.has_key?(&1, m)) end)
      |> Enum.map(&normalize_metric/1)
      |> Enum.uniq()

    data = accumulate(rows, metrics)
    {:ok, compute_anomalies(data, metrics)}
  end

  def detect_anomalies(_, _), do: {:ok, []}

  defp accumulate(rows, metrics) do
    Enum.reduce(rows, %{}, fn row, acc ->
      source = to_string(Map.get(row, "source", ""))
      date = to_string(Map.get(row, "date"))

      Enum.reduce(metrics, acc, fn metric, acc2 ->
        value = Map.get(row, metric)

        if is_number(value) do
          acc2
          |> Map.update(source, %{}, & &1)
          |> Map.update!(source, fn date_map ->
            Map.update(date_map, date, %{metric => value}, fn metric_map ->
              Map.update(metric_map, metric, value, &(&1 + value))
            end)
          end)
        else
          acc2
        end
      end)
    end)
  end

  defp compute_anomalies(data, metrics) do
    Enum.flat_map(data, fn {source, by_date} ->
      dates =
        by_date
        |> Map.keys()
        |> Enum.sort()

      Enum.flat_map(metrics, fn metric ->
        compute_metric_anomalies(source, dates, by_date, metric)
      end)
    end)
  end

  defp compute_metric_anomalies(source, dates, by_date, metric) do
    Enum.reduce(Enum.sort(dates), {nil, []}, fn date, {prev_val, acc} ->
      curr_val = get_in(by_date, [date, metric])

      {new_prev, new_acc} =
        if is_number(curr_val) and is_number(prev_val) and prev_val != 0 do
          change = (curr_val - prev_val) / prev_val * 100
          if abs(change) > 25 do
            anomaly = %{
              metric: label_metric(metric),
              date: date,
              percent_change: Float.round(abs(change), 2),
              direction: if(change > 0, do: :up, else: :down),
              source: source
            }
            {curr_val, [anomaly | acc]}
          else
            {curr_val, acc}
          end
        else
          {curr_val || prev_val, acc}
        end

      {new_prev, new_acc}
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp normalize_metric("cpc"), do: "cost_per_click"
  defp normalize_metric(metric), do: metric

  defp label_metric("cost_per_click"), do: "cpc"
  defp label_metric(metric), do: metric

  @spec summarize_anomalies(list()) :: {:ok, String.t()} | {:error, any()}
  def summarize_anomalies(anomalies) when is_list(anomalies) do
    prompt = """
      You're a senior marketing analyst. Summarize these anomalies in plain language.

      Each item has a `metric`, `date`, `source`, `percent_change`, and `direction`.

      Focus on exactly what happened, where, and when — no general advice.

      Example:
      - Facebook CPC spiked 42% on Jan 12 
      - LinkedIn conversions dropped 30% on Jan 15

      Now generate a summary from this JSON:

      #{Jason.encode!(anomalies)}

      Return a short list of bullet points (2–5 total).
    """

    case DashboardGen.OpenAIClient.ask(prompt) do
      {:ok, response} -> {:ok, response}
      {:error, _} -> {:error, "Analysis generation failed"}
    end
  end

  def summarize_anomalies(_), do: {:error, :invalid_arguments}
end

