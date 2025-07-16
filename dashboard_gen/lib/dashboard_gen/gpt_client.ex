defmodule DashboardGen.GPTClient do
  @moduledoc """
  Client for communicating with the OpenAI chat completions API.

  Provides a single `get_chart_spec/1` function which sends a prompt to
  OpenAI and expects a JSON response describing charts.
  """

  @openai_url "https://api.openai.com/v1/chat/completions"

  @doc """
  Sends the given prompt to the OpenAI API and returns the decoded chart
  specification on success.
  """
  @spec get_chart_spec(String.t()) :: {:ok, map()} | {:error, String.t()}
  def get_chart_spec(prompt) when is_binary(prompt) do
    api_key = fetch_api_key!()

    body = %{
      model: "gpt-4",
      messages: [
        %{role: "system", content: default_system_prompt()},
        %{role: "user", content: prompt}
      ]
    }

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    with {:ok, %Req.Response{status: 200, body: %{"choices" => choices}}} <-
           Req.post(@openai_url, json: body, headers: headers),
         %{"message" => %{"content" => content}} <- List.first(choices),
         _ = IO.inspect(content, label: "GPT RAW RESPONSE"),
         cleaned <- content |> extract_json_block() |> String.trim(),
         {:ok, decoded} <- Jason.decode(cleaned),
         true <- Map.has_key?(decoded, "charts") do
      {:ok, decoded}
    else
      {:error, %Req.Response{body: body}} ->
        {:error, inspect(body)}

      {:error, reason} ->
        {:error, inspect(reason)}

      _ ->
        {:error, "Invalid chart spec"}
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

  defp extract_json_block(content) when is_binary(content) do
    regex = ~r/```(?:json)?\s*(?<json>.*?)\s*```/ms

    case Regex.named_captures(regex, content) do
      %{"json" => json} -> json
      _ -> content
    end
  end

  defp fetch_api_key! do
    System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY environment variable is missing"
  end
end
