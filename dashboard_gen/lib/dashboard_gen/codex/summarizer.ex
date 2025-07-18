defmodule DashboardGen.Codex.Summarizer do
  @moduledoc """
  Generate short textual insights for chart data using GPT.
  """

  alias DashboardGen.CodexClient

  @spec summarize(String.t(), list(), list()) :: {:ok, String.t()} | {:error, any()}
  def summarize(query_text, headers, rows)
      when is_binary(query_text) and is_list(headers) and is_list(rows) do
    prompt = """
    You're a marketing analyst. Given the following query and data, return a short summary (2–3 sentences) with insights.

    Query: #{query_text}

    Headers: #{inspect(headers)}

    First few rows:
    #{Jason.encode!(Enum.take(rows, 5))}

    Focus on trends, spikes, or performance anomalies.
    """

    CodexClient.ask(prompt)
  end

  def summarize(_, _, _), do: {:error, :invalid_arguments}
end
