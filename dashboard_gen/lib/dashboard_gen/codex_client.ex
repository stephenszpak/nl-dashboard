defmodule DashboardGen.CodexClient do
  @moduledoc false

  @openai_url "https://api.openai.com/v1/chat/completions"

  @spec ask(String.t()) :: {:ok, String.t()} | {:error, any()}
  def ask(prompt) when is_binary(prompt) do
    with api_key when is_binary(api_key) <-
           System.get_env("OPENAI_API_KEY") ||
             {:error, "OPENAI_API_KEY environment variable is missing"},
         body <- %{model: "gpt-3.5-turbo", messages: [%{role: "user", content: prompt}]},
         headers <- [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}] do
      
      # Make request with timeout and retry configuration
      case Req.post(@openai_url, 
        json: body, 
        headers: headers,
        receive_timeout: 60_000,  # 60 second timeout
        connect_options: [timeout: 30_000],  # 30 second connection timeout
        retry: :transient,
        max_retries: 2
      ) do
        {:ok, %Req.Response{status: 200, body: %{"choices" => choices}}} ->
          case List.first(choices) do
            %{"message" => %{"content" => content}} ->
              {:ok, String.trim(content)}
            _ ->
              {:error, "Invalid response format from OpenAI"}
          end
        
        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, "OpenAI API error (#{status}): #{inspect(body)}"}
        
        {:error, %Req.TransportError{reason: reason}} ->
          require Logger
          Logger.error("OpenAI API Transport Error: #{inspect(reason)}")
          {:error, "Connection error: #{inspect(reason)}. Please check your internet connection and try again."}
        
        {:error, reason} ->
          require Logger
          Logger.error("OpenAI API Request Error: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, "OPENAI_API_KEY environment variable is missing"}
    end
  end
end
