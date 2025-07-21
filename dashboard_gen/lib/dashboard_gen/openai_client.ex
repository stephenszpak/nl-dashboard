defmodule DashboardGen.OpenAIClient do
  @moduledoc """
  Unified OpenAI API client for all chat completion needs.
  
  Supports:
  - General text completion
  - Structured JSON responses
  - Chart specification generation
  - Robust error handling with retries
  """

  require Logger

  @openai_url "https://api.openai.com/v1/chat/completions"
  @default_model "gpt-3.5-turbo"
  @default_timeout 60_000
  @default_connect_timeout 30_000
  @default_max_retries 2

  @type message :: %{role: String.t(), content: String.t()}
  @type completion_options :: %{
    optional(:model) => String.t(),
    optional(:system_prompt) => String.t(),
    optional(:timeout) => integer(),
    optional(:max_retries) => integer(),
    optional(:temperature) => float()
  }

  @doc """
  Send a simple text prompt and get a text response.
  
  ## Examples
      iex> OpenAIClient.ask("What is 2+2?")
      {:ok, "2+2 equals 4."}
      
      iex> OpenAIClient.ask("Explain AI", %{model: "gpt-4"})
      {:ok, "Artificial Intelligence is..."}
  """
  @spec ask(String.t(), completion_options()) :: {:ok, String.t()} | {:error, String.t()}
  def ask(prompt, opts \\ %{}) when is_binary(prompt) do
    messages = build_messages(prompt, opts)
    
    case complete_chat(messages, opts) do
      {:ok, response} -> {:ok, String.trim(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate chart specifications from a prompt.
  Returns structured JSON for chart configuration.
  
  ## Examples
      iex> OpenAIClient.get_chart_spec("Show sales by month", %{"month" => "Month", "sales" => "Sales"})
      {:ok, %{"charts" => [%{"type" => "bar", "title" => "Sales by Month", "x" => "month", "y" => ["sales"]}]}}
  """
  @spec get_chart_spec(String.t(), map(), completion_options()) :: {:ok, map()} | {:error, String.t()}
  def get_chart_spec(prompt, headers, opts \\ %{}) when is_binary(prompt) and is_map(headers) do
    system_prompt = chart_system_prompt(headers)
    opts_with_system = Map.put(opts, :system_prompt, system_prompt)
    
    case ask(prompt, opts_with_system) do
      {:ok, response} ->
        response
        |> extract_json_block()
        |> clean_json()
        |> parse_and_validate_chart(Map.keys(headers))
        
      {:error, reason} -> 
        {:error, reason}
    end
  end

  @doc """
  Send a structured prompt with system message and get JSON response.
  Useful for getting structured data from OpenAI.
  """
  @spec ask_for_json(String.t(), String.t(), completion_options()) :: {:ok, map()} | {:error, String.t()}
  def ask_for_json(prompt, system_prompt, opts \\ %{}) do
    opts_with_system = Map.put(opts, :system_prompt, system_prompt)
    
    case ask(prompt, opts_with_system) do
      {:ok, response} ->
        response
        |> extract_json_block()
        |> clean_json()
        |> Jason.decode()
        |> case do
          {:ok, decoded} -> {:ok, decoded}
          {:error, reason} -> {:error, "Failed to decode JSON: #{inspect(reason)}"}
        end
        
      {:error, reason} -> 
        {:error, reason}
    end
  end

  ## Private Functions

  defp complete_chat(messages, opts) do
    with {:ok, api_key} <- get_api_key(),
         body <- build_request_body(messages, opts),
         headers <- build_headers(api_key),
         request_opts <- build_request_options(opts),
         {:ok, response} <- make_request(body, headers, request_opts) do
      extract_content(response)
    end
  end

  defp get_api_key do
    case System.get_env("OPENAI_API_KEY") do
      key when is_binary(key) -> {:ok, key}
      _ -> {:error, "OPENAI_API_KEY environment variable is missing"}
    end
  end

  defp build_messages(prompt, %{system_prompt: system_prompt}) do
    [
      %{role: "system", content: system_prompt},
      %{role: "user", content: prompt}
    ]
  end
  
  defp build_messages(prompt, _opts) do
    [%{role: "user", content: prompt}]
  end

  defp build_request_body(messages, opts) do
    %{
      model: Map.get(opts, :model, @default_model),
      messages: messages
    }
    |> maybe_add_temperature(opts)
  end

  defp maybe_add_temperature(body, %{temperature: temp}) when is_number(temp) do
    Map.put(body, :temperature, temp)
  end
  defp maybe_add_temperature(body, _opts), do: body

  defp build_headers(api_key) do
    [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]
  end

  defp build_request_options(opts) do
    [
      receive_timeout: Map.get(opts, :timeout, @default_timeout),
      connect_options: [timeout: Map.get(opts, :connect_timeout, @default_connect_timeout)],
      retry: :transient,
      max_retries: Map.get(opts, :max_retries, @default_max_retries)
    ]
  end

  defp make_request(body, headers, request_opts) do
    case Req.post(@openai_url, [json: body, headers: headers] ++ request_opts) do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, response}
        
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("OpenAI API error (#{status}): #{inspect(body)}")
        {:error, "OpenAI API error (#{status}): #{inspect(body)}"}
        
      {:error, %Req.TransportError{reason: reason}} ->
        Logger.error("OpenAI API Transport Error: #{inspect(reason)}")
        {:error, "Connection error: #{inspect(reason)}. Please check your internet connection and try again."}
        
      {:error, reason} ->
        Logger.error("OpenAI API Request Error: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract_content(%Req.Response{body: %{"choices" => choices}}) do
    case List.first(choices) do
      %{"message" => %{"content" => content}} when is_binary(content) ->
        {:ok, content}
      _ ->
        {:error, "Invalid response format from OpenAI"}
    end
  end

  # Chart-specific functions

  @doc "Generate system prompt for chart specification requests"
  def chart_system_prompt(headers) do
    fields = headers |> Map.values() |> Enum.join(", ")
    normalized_fields = headers |> Map.keys() |> Enum.join(", ")

    """
    You are a strict JSON-only API. When given a prompt, respond ONLY with valid JSON in this schema:

    {
      "charts": [
        {
          "type": "bar",
          "title": "title string",
          "x": "x axis field name",
          "y": ["list", "of", "y", "fields"]
        }
      ]
    }

    The available fields are: #{fields}
    Only use the following fields: #{normalized_fields}.

    DO NOT explain anything. DO NOT wrap the response in markdown. DO NOT include code fences. DO NOT add extra text.
    """
    |> String.trim()
  end

  @doc "Extract JSON from a text response, handling code fences"
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

  defp clean_json(json) do
    json
    |> String.replace(~r/,\s*\n\s*}/, "\n}")
    |> String.replace(~r/,\s*\n\s*]/, "\n]")
    |> String.trim()
  end

  defp parse_and_validate_chart(json_string, allowed_fields) do
    case Jason.decode(json_string) do
      {:ok, %{"charts" => charts}} ->
        case validate_charts(charts, allowed_fields) do
          {:ok, valid_charts} -> {:ok, %{"charts" => valid_charts}}
          {:error, reason} -> {:error, reason}
        end
        
      {:ok, decoded} ->
        {:error, "Missing 'charts' key in response: #{inspect(decoded)}"}
        
      {:error, reason} ->
        {:error, "Failed to decode JSON: #{inspect(reason)}"}
    end
  end

  defp validate_charts(charts, allowed_fields) when is_list(charts) do
    charts
    |> Enum.reduce_while({:ok, []}, fn chart, {:ok, acc} ->
      case validate_chart(chart, allowed_fields) do
        {:ok, cleaned} -> {:cont, {:ok, [cleaned | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, charts_rev} -> {:ok, Enum.reverse(charts_rev)}
      error -> error
    end
  end

  defp validate_chart(%{"x" => _x, "y" => y} = chart, _allowed_fields) when is_list(y) do
    {:ok, chart}
  end

  defp validate_chart(_, _), do: {:error, "Invalid chart specification"}
end