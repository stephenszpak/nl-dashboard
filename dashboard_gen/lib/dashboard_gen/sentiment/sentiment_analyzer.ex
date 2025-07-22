defmodule DashboardGen.Sentiment.SentimentAnalyzer do
  @moduledoc """
  AI-powered sentiment analysis using OpenAI and local models.
  Analyzes text content for sentiment, emotions, and topics.
  """
  
  alias DashboardGen.OpenAIClient
  alias DashboardGen.LocalInference
  require Logger
  
  @doc """
  Analyzes text for sentiment using AI models.
  Returns structured sentiment data.
  """
  def analyze_text(content, opts \\ []) do
    model = Keyword.get(opts, :model, :openai)
    company = Keyword.get(opts, :company, "unknown")
    
    case model do
      :openai -> analyze_with_openai(content, company)
      :local -> analyze_with_local(content, company)
      _ -> {:error, "Unsupported model: #{model}"}
    end
  end
  
  @doc """
  Batch analyzes multiple texts for efficiency.
  """
  def batch_analyze(contents, opts \\ []) when is_list(contents) do
    model = Keyword.get(opts, :model, :openai)
    company = Keyword.get(opts, :company, "unknown")
    
    case model do
      :openai -> batch_analyze_with_openai(contents, company)
      :local -> 
        # For local models, analyze individually to avoid overload
        Enum.map(contents, &analyze_with_local(&1, company))
      _ -> {:error, "Unsupported model: #{model}"}
    end
  end
  
  ## OpenAI Analysis
  
  defp analyze_with_openai(content, company) do
    prompt = build_sentiment_prompt(content, company)
    
    case OpenAIClient.ask(prompt) do
      {:ok, response} -> parse_openai_response(response, content)
      {:error, reason} -> 
        Logger.warning("OpenAI sentiment analysis failed: #{reason}")
        {:error, reason}
    end
  end
  
  defp batch_analyze_with_openai(contents, company) do
    prompt = build_batch_sentiment_prompt(contents, company)
    
    case OpenAIClient.ask(prompt) do
      {:ok, response} -> parse_batch_openai_response(response, contents)
      {:error, reason} -> 
        Logger.warning("Batch OpenAI sentiment analysis failed: #{reason}")
        {:error, reason}
    end
  end
  
  defp build_sentiment_prompt(content, company) do
    """
    Analyze the sentiment of the following text about #{company}. 
    
    Text: "#{content}"
    
    Please provide a JSON response with the following structure:
    {
      "sentiment_score": <number between -1.0 and 1.0>,
      "sentiment_label": "<positive/negative/neutral>",
      "confidence": <number between 0.0 and 1.0>,
      "topics": [<array of key topics/keywords>],
      "emotions": {
        "joy": <0-1>,
        "anger": <0-1>,
        "fear": <0-1>,
        "surprise": <0-1>,
        "sadness": <0-1>
      },
      "reasoning": "<brief explanation of sentiment analysis>"
    }
    
    Guidelines:
    - sentiment_score: -1.0 (very negative) to +1.0 (very positive)
    - confidence: How confident you are in this analysis (0-1)
    - topics: Extract 2-5 key topics or themes
    - emotions: Detect emotional undertones
    - Focus on sentiment toward #{company} specifically
    """
  end
  
  defp build_batch_sentiment_prompt(contents, company) do
    numbered_contents = contents
    |> Enum.with_index(1)
    |> Enum.map(fn {content, idx} -> "#{idx}. \"#{content}\"" end)
    |> Enum.join("\n")
    
    """
    Analyze the sentiment of the following texts about #{company}. 
    
    Texts:
    #{numbered_contents}
    
    Please provide a JSON response with an array of analyses:
    [
      {
        "id": 1,
        "sentiment_score": <number between -1.0 and 1.0>,
        "sentiment_label": "<positive/negative/neutral>",
        "confidence": <number between 0.0 and 1.0>,
        "topics": [<array of key topics>],
        "emotions": {"joy": <0-1>, "anger": <0-1>, "fear": <0-1>, "surprise": <0-1>, "sadness": <0-1>}
      },
      ...
    ]
    
    Focus on sentiment toward #{company} specifically.
    """
  end
  
  defp parse_openai_response(response, original_content) do
    case Jason.decode(response) do
      {:ok, %{
        "sentiment_score" => score,
        "sentiment_label" => label,
        "confidence" => confidence,
        "topics" => topics,
        "emotions" => emotions
      } = data} ->
        {:ok, %{
          sentiment_score: ensure_float(score),
          sentiment_label: String.downcase(label),
          confidence: ensure_float(confidence),
          topics: ensure_list(topics),
          emotions: ensure_map(emotions),
          analysis_model: "openai",
          reasoning: Map.get(data, "reasoning"),
          original_content: original_content
        }}
        
      {:ok, _} -> 
        {:error, "Invalid response structure from OpenAI"}
        
      {:error, _} ->
        # Try to extract basic sentiment if JSON parsing fails
        extract_basic_sentiment(response, original_content)
    end
  end
  
  defp parse_batch_openai_response(response, original_contents) do
    case Jason.decode(response) do
      {:ok, analyses} when is_list(analyses) ->
        results = Enum.map(analyses, fn analysis ->
          case analysis do
            %{
              "id" => id,
              "sentiment_score" => score,
              "sentiment_label" => label,
              "confidence" => confidence,
              "topics" => topics,
              "emotions" => emotions
            } ->
              original_content = Enum.at(original_contents, id - 1, "")
              {:ok, %{
                sentiment_score: ensure_float(score),
                sentiment_label: String.downcase(label),
                confidence: ensure_float(confidence),
                topics: ensure_list(topics),
                emotions: ensure_map(emotions),
                analysis_model: "openai",
                original_content: original_content
              }}
            _ ->
              {:error, "Invalid analysis structure"}
          end
        end)
        {:ok, results}
        
      {:error, _} ->
        {:error, "Failed to parse batch response"}
    end
  end
  
  ## Local Model Analysis
  
  defp analyze_with_local(content, company) do
    prompt = build_local_sentiment_prompt(content, company)
    
    case LocalInference.ask(prompt) do
      {:ok, response} -> parse_local_response(response, content)
      {:error, reason} -> 
        Logger.warning("Local sentiment analysis failed: #{reason}")
        # Fallback to OpenAI
        analyze_with_openai(content, company)
    end
  end
  
  defp build_local_sentiment_prompt(content, company) do
    """
    Analyze sentiment about #{company} in this text: "#{content}"
    
    Respond with: SENTIMENT_SCORE:<-1.0 to 1.0> LABEL:<positive/negative/neutral> CONFIDENCE:<0.0 to 1.0>
    """
  end
  
  defp parse_local_response(response, original_content) do
    # Parse simple local model response format
    case Regex.run(~r/SENTIMENT_SCORE:([-\d.]+)\s+LABEL:(\w+)\s+CONFIDENCE:([\d.]+)/, response) do
      [_, score_str, label, confidence_str] ->
        {:ok, %{
          sentiment_score: String.to_float(score_str),
          sentiment_label: String.downcase(label),
          confidence: String.to_float(confidence_str),
          topics: extract_simple_topics(original_content),
          emotions: %{},
          analysis_model: "local",
          original_content: original_content
        }}
      _ ->
        # Simple keyword-based fallback
        analyze_with_keywords(original_content)
    end
  end
  
  ## Fallback Methods
  
  defp extract_basic_sentiment(response, original_content) do
    # Try to extract sentiment from free-form response
    sentiment_score = cond do
      String.contains?(String.downcase(response), ["very positive", "excellent", "great"]) -> 0.8
      String.contains?(String.downcase(response), ["positive", "good"]) -> 0.4
      String.contains?(String.downcase(response), ["very negative", "terrible", "awful"]) -> -0.8
      String.contains?(String.downcase(response), ["negative", "bad"]) -> -0.4
      true -> 0.0
    end
    
    sentiment_label = cond do
      sentiment_score > 0.1 -> "positive"
      sentiment_score < -0.1 -> "negative"
      true -> "neutral"
    end
    
    {:ok, %{
      sentiment_score: sentiment_score,
      sentiment_label: sentiment_label,
      confidence: 0.5,
      topics: extract_simple_topics(original_content),
      emotions: %{},
      analysis_model: "openai_fallback",
      original_content: original_content
    }}
  end
  
  defp analyze_with_keywords(content) do
    positive_keywords = ["good", "great", "excellent", "love", "amazing", "best", "awesome", "fantastic"]
    negative_keywords = ["bad", "terrible", "awful", "hate", "worst", "horrible", "disgusting", "disappointing"]
    
    content_lower = String.downcase(content)
    positive_count = Enum.count(positive_keywords, &String.contains?(content_lower, &1))
    negative_count = Enum.count(negative_keywords, &String.contains?(content_lower, &1))
    
    sentiment_score = case {positive_count, negative_count} do
      {0, 0} -> 0.0
      {p, n} when p > n -> min(0.8, p * 0.2)
      {p, n} when n > p -> max(-0.8, n * -0.2)
      _ -> 0.0
    end
    
    {:ok, %{
      sentiment_score: sentiment_score,
      sentiment_label: if(sentiment_score > 0.1, do: "positive", else: if(sentiment_score < -0.1, do: "negative", else: "neutral")),
      confidence: 0.3,
      topics: extract_simple_topics(content),
      emotions: %{},
      analysis_model: "keyword_fallback",
      original_content: content
    }}
  end
  
  defp extract_simple_topics(content) do
    # Extract potential topics using simple word frequency
    content
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Enum.map(&elem(&1, 0))
  end
  
  ## Helper functions
  
  defp ensure_float(value) when is_float(value), do: value
  defp ensure_float(value) when is_integer(value), do: value / 1.0
  defp ensure_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp ensure_float(_), do: 0.0
  
  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []
  
  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}
end