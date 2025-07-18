defmodule DashboardGen.CodexClient do
  @moduledoc false

  @openai_url "https://api.openai.com/v1/chat/completions"

  @spec ask(String.t()) :: {:ok, String.t()} | {:error, any()}
  def ask(prompt) when is_binary(prompt) do
    with api_key when is_binary(api_key) <-
           System.get_env("OPENAI_API_KEY") ||
             {:error, "OPENAI_API_KEY environment variable is missing"},
         body <- %{model: "gpt-3.5-turbo", messages: [%{role: "user", content: prompt}]},
         headers <- [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}],
         {:ok, %Req.Response{status: 200, body: %{"choices" => choices}}} <-
           Req.post(@openai_url, json: body, headers: headers),
         %{"message" => %{"content" => content}} <- List.first(choices) do
      {:ok, String.trim(content)}
    else
      {:error, %Req.Response{body: body}} -> {:error, inspect(body)}
      {:error, reason} -> {:error, inspect(reason)}
      nil -> {:error, "OPENAI_API_KEY environment variable is missing"}
      _ -> {:error, "Invalid response from OpenAI"}
    end
  end
end
