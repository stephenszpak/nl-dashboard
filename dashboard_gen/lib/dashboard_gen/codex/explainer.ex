defmodule DashboardGen.Codex.Explainer do
  @moduledoc """
  Generate explanations for query results using GPT via `DashboardGen.CodexClient`.
  """

  alias DashboardGen.CodexClient

  @doc """
  Explain the provided query results.
  """
  @spec explain(String.t(), list(), list()) :: {:ok, String.t()} | {:error, any()}
  def explain(query_text, headers, rows)
      when is_binary(query_text) and is_list(headers) and is_list(rows) do
    prompt = """
    You're a senior marketing analyst. What does this data show?

    Query: #{query_text}
    Headers: #{inspect(headers)}
    Data: #{Jason.encode!(Enum.take(rows, 5))}

    Provide 2–3 sentences summarizing the result.
    """

    CodexClient.ask(prompt)
  end

  def explain(_, _, _), do: {:error, :invalid_arguments}

  @doc """
  Suggest reasons why the results might have occurred.
  """
  @spec why(String.t(), list(), list()) :: {:ok, String.t()} | {:error, any()}
  def why(query_text, headers, rows)
      when is_binary(query_text) and is_list(headers) and is_list(rows) do
    prompt = """
    You're a marketing performance analyst. Based on this data and query, why might these results have occurred?

    Query: #{query_text}
    Headers: #{inspect(headers)}
    Data: #{Jason.encode!(Enum.take(rows, 5))}

    Give possible causes like timing, platform behavior, or user engagement shifts. Be concise.
    """

    CodexClient.ask(prompt)
  end

  def why(_, _, _), do: {:error, :invalid_arguments}
end
