defmodule DashboardGen.GPT do
  @moduledoc "Handles communication with OpenAI API"

  def ask(prompt) do
    body = %{model: "gpt-3.5-turbo", messages: [%{role: "user", content: prompt}]}

    case OpenAI.chat_completion(body) do
      {:ok, %{choices: [%{"message" => %{"content" => content}}]}} ->
        Jason.decode(content)

      other ->
        {:error, other}
    end
  end
end
