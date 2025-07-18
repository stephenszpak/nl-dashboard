defmodule DashboardGen.Codex.Explainer do
  @moduledoc """
  Generate explanations for query results using GPT via `DashboardGen.CodexClient`.
  """

  alias DashboardGen.CodexClient

  @doc """
  Explain the provided query and data with a short summary.
  """
  @spec explain(String.t(), list(), list()) :: {:ok, String.t()} | {:error, any()}
  def explain(query_text, headers, rows)
      when is_binary(query_text) and is_list(headers) and is_list(rows) do
    prompt = """
    You're a senior marketing analyst. Explain the following query and data in 2–4 sentences.

    Query: #{query_text}
    Headers: #{inspect(headers)}
    First few rows: #{Jason.encode!(Enum.take(rows, 5))}

    Explain what the data shows — trends, notable values, and high-level takeaways.
    """

    CodexClient.ask(prompt)
  end

  def explain(_, _, _), do: {:error, :invalid_arguments}

  @doc """
  Suggest reasons why the results might have occurred based on the data.
  """
  @spec why(String.t(), list(), list()) :: {:ok, String.t()} | {:error, any()}
  def why(query_text, headers, rows)
      when is_binary(query_text) and is_list(headers) and is_list(rows) do
    prompt = """
    You're a marketing performance analyst. Based on this data, why might these results have occurred?

    Query: #{query_text}
    Headers: #{inspect(headers)}
    First few rows: #{Jason.encode!(Enum.take(rows, 5))}

    Suggest plausible causes related to campaign timing, channels, or audience behavior. Be concise (2–3 sentences).
    """

    CodexClient.ask(prompt)
  end

  def why(_, _, _), do: {:error, :invalid_arguments}
end
