defmodule DashboardGen.LocalInference do
  @moduledoc """
  Local GPT inference integration with Ollama and OpenRouter fallback.
  
  Provides local AI inference capabilities with automatic failover to cloud services.
  Supports multiple local models and dynamic model selection based on task complexity.
  """
  
  require Logger
  alias DashboardGen.CodexClient
  
  @ollama_base_url "http://localhost:11434"
  @openrouter_base_url "https://openrouter.ai/api/v1"
  
  # Model configurations
  @local_models %{
    "llama3.2:3b" => %{
      size: :small,
      use_cases: [:classification, :simple_analysis],
      max_tokens: 4096,
      speed: :fast
    },
    "llama3.2:8b" => %{
      size: :medium, 
      use_cases: [:content_tagging, :trend_analysis],
      max_tokens: 8192,
      speed: :medium
    },
    "llama3.1:70b" => %{
      size: :large,
      use_cases: [:complex_analysis, :strategic_planning],
      max_tokens: 32768,
      speed: :slow
    }
  }
  
  @openrouter_models %{
    "meta-llama/llama-3.2-3b-instruct:free" => %{
      cost: :free,
      use_cases: [:classification, :simple_analysis]
    },
    "meta-llama/llama-3.1-8b-instruct:free" => %{
      cost: :free,
      use_cases: [:content_tagging, :trend_analysis]
    },
    "anthropic/claude-3.5-sonnet" => %{
      cost: :paid,
      use_cases: [:complex_analysis, :strategic_planning]
    }
  }
  
  @doc """
  Intelligent inference with automatic model selection and fallback
  """
  def ask(prompt, options \\ %{}) do
    task_type = determine_task_type(prompt, options)
    complexity = determine_complexity(prompt, options)
    
    # Try local inference first
    case try_local_inference(prompt, task_type, complexity, options) do
      {:ok, response} -> 
        Logger.info("Local inference successful with #{get_selected_local_model(task_type, complexity)}")
        {:ok, response}
        
      {:error, :local_unavailable} ->
        Logger.info("Local inference unavailable, falling back to OpenRouter")
        try_openrouter_fallback(prompt, task_type, complexity, options)
        
      {:error, :model_overloaded} ->
        Logger.info("Local model overloaded, falling back to cloud")
        try_openrouter_fallback(prompt, task_type, complexity, options)
        
      {:error, reason} ->
        Logger.warn("Local inference failed: #{reason}, trying cloud fallback")
        case try_openrouter_fallback(prompt, task_type, complexity, options) do
          {:ok, response} -> {:ok, response}
          {:error, _} -> DashboardGen.OpenAIClient.ask(prompt) # Final fallback to OpenAI
        end
    end
  end
  
  @doc """
  Check if local inference is available
  """
  def local_available? do
    case HTTPoison.get("#{@ollama_base_url}/api/tags", [], timeout: 5000) do
      {:ok, %{status_code: 200}} -> true
      _ -> false
    end
  end
  
  @doc """
  List available local models
  """
  def list_local_models do
    case HTTPoison.get("#{@ollama_base_url}/api/tags") do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"models" => models}} ->
            available_models = Enum.map(models, &(&1["name"]))
            {:ok, available_models}
          _ -> {:error, "Failed to parse models response"}
        end
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Pull a model if not available locally
  """
  def ensure_model(model_name) do
    case HTTPoison.post(
      "#{@ollama_base_url}/api/pull",
      Jason.encode!(%{"name" => model_name}),
      [{"Content-Type", "application/json"}],
      timeout: 300_000 # 5 minutes for model download
    ) do
      {:ok, %{status_code: 200}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Get inference performance metrics
  """
  def get_performance_metrics do
    %{
      local_available: local_available?(),
      local_models: get_available_local_models(),
      openrouter_available: test_openrouter_connection(),
      fallback_chain: [:local, :openrouter, :openai],
      last_check: DateTime.utc_now()
    }
  end
  
  # Private functions
  
  defp try_local_inference(prompt, task_type, complexity, options) do
    if local_available?() do
      model = get_selected_local_model(task_type, complexity)
      
      case make_ollama_request(prompt, model, options) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :local_unavailable}
    end
  end
  
  defp try_openrouter_fallback(prompt, task_type, complexity, options) do
    model = get_selected_openrouter_model(task_type, complexity)
    
    case make_openrouter_request(prompt, model, options) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp make_ollama_request(prompt, model, options) do
    payload = %{
      "model" => model,
      "prompt" => prompt,
      "stream" => false,
      "options" => %{
        "temperature" => Map.get(options, :temperature, 0.7),
        "top_p" => Map.get(options, :top_p, 0.9),
        "num_predict" => Map.get(options, :max_tokens, 2048)
      }
    }
    
    case HTTPoison.post(
      "#{@ollama_base_url}/api/generate",
      Jason.encode!(payload),
      [{"Content-Type", "application/json"}],
      timeout: 60_000
    ) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"response" => response}} -> {:ok, String.trim(response)}
          {:error, _} -> {:error, "Failed to parse Ollama response"}
        end
        
      {:ok, %{status_code: status}} ->
        {:error, "Ollama request failed with status #{status}"}
        
      {:error, %{reason: :timeout}} ->
        {:error, :model_overloaded}
        
      {:error, reason} ->
        {:error, "Ollama request failed: #{inspect(reason)}"}
    end
  end
  
  defp make_openrouter_request(prompt, model, options) do
    api_key = System.get_env("OPENROUTER_API_KEY")
    
    if api_key do
      payload = %{
        "model" => model,
        "messages" => [%{"role" => "user", "content" => prompt}],
        "temperature" => Map.get(options, :temperature, 0.7),
        "max_tokens" => Map.get(options, :max_tokens, 2048)
      }
      
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"},
        {"HTTP-Referer", "http://localhost:4000"},
        {"X-Title", "DashboardGen Agent System"}
      ]
      
      case HTTPoison.post(
        "#{@openrouter_base_url}/chat/completions",
        Jason.encode!(payload),
        headers,
        timeout: 60_000
      ) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"choices" => [%{"message" => %{"content" => response}} | _]}} ->
              {:ok, String.trim(response)}
            {:error, _} -> {:error, "Failed to parse OpenRouter response"}
          end
          
        {:ok, %{status_code: status, body: body}} ->
          {:error, "OpenRouter request failed with status #{status}: #{body}"}
          
        {:error, reason} ->
          {:error, "OpenRouter request failed: #{inspect(reason)}"}
      end
    else
      {:error, "OPENROUTER_API_KEY not set"}
    end
  end
  
  defp determine_task_type(prompt, options) do
    Map.get(options, :task_type) || classify_task_type(prompt)
  end
  
  defp classify_task_type(prompt) do
    prompt_lower = String.downcase(prompt)
    
    cond do
      String.contains?(prompt_lower, ["classify", "tag", "categorize"]) ->
        :classification
      String.contains?(prompt_lower, ["analyze", "insights", "what", "how"]) ->
        :content_tagging
      String.contains?(prompt_lower, ["trend", "pattern", "over time"]) ->
        :trend_analysis
      String.contains?(prompt_lower, ["strategy", "recommend", "plan"]) ->
        :strategic_planning
      String.length(prompt) < 100 ->
        :simple_analysis
      true ->
        :complex_analysis
    end
  end
  
  defp determine_complexity(prompt, options) do
    Map.get(options, :complexity) || classify_complexity(prompt)
  end
  
  defp classify_complexity(prompt) do
    length = String.length(prompt)
    word_count = length(String.split(prompt))
    
    cond do
      length < 200 and word_count < 30 -> :simple
      length < 1000 and word_count < 150 -> :medium
      true -> :complex
    end
  end
  
  defp get_selected_local_model(task_type, complexity) do
    # Select best local model based on task and complexity
    case {task_type, complexity} do
      {_, :simple} -> "llama3.2:3b"
      {:classification, _} -> "llama3.2:3b"
      {:simple_analysis, _} -> "llama3.2:3b"
      {_, :medium} -> "llama3.2:8b"
      {:content_tagging, _} -> "llama3.2:8b"
      {:trend_analysis, _} -> "llama3.2:8b"
      {_, :complex} -> "llama3.1:70b"
      {:strategic_planning, _} -> "llama3.1:70b"
      {:complex_analysis, _} -> "llama3.1:70b"
      _ -> "llama3.2:8b" # Default fallback
    end
  end
  
  defp get_selected_openrouter_model(task_type, complexity) do
    case {task_type, complexity} do
      {_, :simple} -> "meta-llama/llama-3.2-3b-instruct:free"
      {:classification, _} -> "meta-llama/llama-3.2-3b-instruct:free"
      {:simple_analysis, _} -> "meta-llama/llama-3.2-3b-instruct:free"
      {_, :medium} -> "meta-llama/llama-3.1-8b-instruct:free"
      {:content_tagging, _} -> "meta-llama/llama-3.1-8b-instruct:free"
      {:trend_analysis, _} -> "meta-llama/llama-3.1-8b-instruct:free"
      {_, :complex} -> "anthropic/claude-3.5-sonnet"
      {:strategic_planning, _} -> "anthropic/claude-3.5-sonnet"
      {:complex_analysis, _} -> "anthropic/claude-3.5-sonnet"
      _ -> "meta-llama/llama-3.1-8b-instruct:free"
    end
  end
  
  defp get_available_local_models do
    case list_local_models() do
      {:ok, models} -> models
      _ -> []
    end
  end
  
  defp test_openrouter_connection do
    api_key = System.get_env("OPENROUTER_API_KEY")
    
    if api_key do
      case HTTPoison.get(
        "#{@openrouter_base_url}/models",
        [{"Authorization", "Bearer #{api_key}"}],
        timeout: 5000
      ) do
        {:ok, %{status_code: 200}} -> true
        _ -> false
      end
    else
      false
    end
  end
end