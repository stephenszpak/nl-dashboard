defmodule DashboardGen.GPTClient do
  @moduledoc """
  Client for communicating with the OpenAI chat completions API.

  Provides a single `get_chart_spec/1` function which sends a prompt to
  OpenAI and expects a JSON response describing charts.
  """

  @openai_url "https://api.openai.com/v1/chat/completions"

  @csv_headers [
    "Month",
    "Ad Spend",
    "Conversions",
    "CTR",
    "Impressions",
    "Cost Per Click",
    "Campaign"
  ]

  @doc """
  Sends the given prompt to the OpenAI API and returns the decoded chart
  specification on success.
  """
  @spec get_chart_spec(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_chart_spec(prompt) when is_binary(prompt) do
    with api_key when is_binary(api_key) <-
           System.get_env("OPENAI_API_KEY") ||
             {:error, "OPENAI_API_KEY environment variable is missing"},
         body <- %{
           model: "gpt-3.5-turbo",
           messages: [
             %{role: "system", content: default_system_prompt()},
             %{role: "user", content: prompt}
           ]
         },
         headers <- [
           {"authorization", "Bearer #{api_key}"},
           {"content-type", "application/json"}
         ],
         {:ok, %Req.Response{status: 200, body: %{"choices" => choices}}} <-
           Req.post(@openai_url, json: body, headers: headers),
         %{"message" => %{"content" => content}} <- List.first(choices) do
      IO.inspect(content, label: "GPT RAW RESPONSE")
      cleaned = content |> extract_json_block() |> String.trim()

      case Jason.decode(cleaned) do
        {:ok, decoded} ->
          if is_map(decoded) and Map.has_key?(decoded, "charts") do
            validate_and_normalize(decoded)
          else
            {:error, "Missing 'charts' key in response: #{inspect(decoded)}"}
          end

        {:error, reason} ->
          {:error, "Failed to decode JSON: #{inspect(reason)}"}
      end
    else
      {:error, %Req.Response{body: body}} ->
        {:error, inspect(body)}

      {:error, reason} ->
        {:error, inspect(reason)}

      nil ->
        {:error, "OPENAI_API_KEY environment variable is missing"}

      _ ->
        {:error, "Invalid response from OpenAI"}
    end
  end

  @doc """
  Returns the default system prompt instructing the model to reply with a
  strict JSON schema.
  """
  @spec default_system_prompt() :: String.t()
  def default_system_prompt do
    """
    You are a strict JSON-only API. When given a prompt, respond ONLY with valid JSON in this schema:

    {
      "charts": [
        {
          "type": "bar",
          "title": "title string",
          "x": "x axis field name",
          "y": ["list", "of", "y", "fields"],
          "data_source": "mock_marketing_data.csv"
        }
      ]
    }

    DO NOT explain anything. DO NOT wrap the response in markdown. DO NOT include code fences. DO NOT add extra text.
    """
    |> String.trim()
  end

  def extract_json_block(content) when is_binary(content) do
    fence_regex = ~r/```(?:json)?\s*(?<json>.*?)\s*```/ms

    cond do
      match = Regex.named_captures(fence_regex, content) ->
        match["json"]

      Regex.match?(~r/^\s*\{.*\}\s*$/ms, content) ->
        content

      match = Regex.run(~r/\{.*\}/ms, content) ->
        List.first(match)

      true ->
        content
    end
  end

  defp validate_and_normalize(%{"charts" => charts}) do
    with {:ok, valid_charts} <- validate_charts(charts) do
      {:ok, %{"charts" => valid_charts}}
    end
  end

  defp validate_charts(charts) when is_list(charts) do
    charts
    |> Enum.reduce_while({:ok, []}, fn chart, {:ok, acc} ->
      case validate_chart(chart) do
        {:ok, cleaned} -> {:cont, {:ok, [cleaned | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, charts_rev} -> {:ok, Enum.reverse(charts_rev)}
      error -> error
    end
  end

  defp validate_chart(%{"x" => x, "y" => y} = chart) when is_list(y) do
    cond do
      x not in @csv_headers ->
        {:error, "Unknown x field '#{x}'"}

      Enum.any?(y, &(&1 not in @csv_headers)) ->
        bad = Enum.filter(y, &(&1 not in @csv_headers)) |> Enum.join(", ")
        {:error, "Unknown y fields: #{bad}"}

      true ->
        chart =
          chart
          |> Map.put("data_source", "mock_marketing_data.csv")

        {:ok, chart}
    end
  end

  defp validate_chart(_), do: {:error, "Invalid chart specification"}
end
