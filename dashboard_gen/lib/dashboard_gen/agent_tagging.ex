defmodule DashboardGen.AgentTagging do
  @moduledoc """
  Sophisticated GPT-powered content tagging and classification system.
  
  Automatically tags content with topics, sentiment, competitive intelligence insights,
  and strategic relevance using AI analysis.
  """
  
  alias DashboardGen.CodexClient
  require Logger
  
  @predefined_topics [
    # Financial Services
    "ESG", "Sustainable Investing", "Asset Management", "Wealth Management", "Retirement Planning",
    "Portfolio Management", "Risk Management", "Alternative Investments", "Fixed Income", "Equities",
    
    # Technology 
    "AI", "Artificial Intelligence", "Machine Learning", "Fintech", "Digital Transformation",
    "Blockchain", "Cryptocurrency", "Robo-Advisors", "APIs", "Cloud Computing", "Cybersecurity",
    
    # Market & Economic
    "Market Volatility", "Interest Rates", "Inflation", "Economic Outlook", "Regulatory Changes",
    "Market Analysis", "Investment Strategy", "Performance", "Benchmarking",
    
    # Business Strategy
    "Mergers & Acquisitions", "Partnerships", "Product Launch", "Client Services", 
    "Thought Leadership", "Research", "Innovation", "Expansion", "Restructuring",
    
    # Competitive Intelligence
    "Competitive Analysis", "Market Share", "Pricing Strategy", "Client Acquisition",
    "Brand Positioning", "Marketing Campaign", "Leadership Changes", "Earnings"
  ]
  
  @sentiment_categories ["Positive", "Negative", "Neutral", "Mixed"]
  @strategic_relevance ["High", "Medium", "Low"]
  @content_types ["Press Release", "Social Media", "Research Report", "Blog Post", "News Article", "Earnings Call"]
  
  @doc """
  Tag a single piece of content with comprehensive metadata
  """
  def tag_content(content) when is_map(content) do
    prompt = build_tagging_prompt(content)
    
    case CodexClient.ask(prompt) do
      {:ok, response} -> parse_tagging_response(response, content)
      {:error, reason} -> 
        Logger.error("Tagging failed: #{reason}")
        default_tags(content)
    end
  end
  
  @doc """
  Batch tag multiple pieces of content
  """
  def tag_content_batch(content_list) when is_list(content_list) do
    content_list
    |> Enum.chunk_every(5) # Process in batches of 5
    |> Enum.flat_map(&process_batch/1)
  end
  
  @doc """
  Extract and tag trending topics from recent content
  """
  def detect_trending_topics(content_list, days_back \\ 7) do
    prompt = build_trending_analysis_prompt(content_list, days_back)
    
    case CodexClient.ask(prompt) do
      {:ok, response} -> parse_trending_response(response)
      {:error, _} -> default_trending_topics()
    end
  end
  
  @doc """
  Analyze competitive intelligence significance
  """
  def analyze_competitive_significance(content, competitor_name) do
    prompt = build_competitive_analysis_prompt(content, competitor_name)
    
    case CodexClient.ask(prompt) do
      {:ok, response} -> parse_competitive_analysis(response)
      {:error, _} -> default_competitive_analysis()
    end
  end
  
  defp build_tagging_prompt(content) do
    """
    CONTENT TAGGING ANALYSIS
    
    Analyze this content and provide structured tagging:
    
    CONTENT:
    Title: #{Map.get(content, :title) || "N/A"}
    Text: #{String.slice(Map.get(content, :text) || Map.get(content, :description) || "", 0, 1000)}
    Source: #{Map.get(content, :source) || "Unknown"}
    Date: #{Map.get(content, :date) || "Unknown"}
    
    PROVIDE ANALYSIS IN THIS EXACT FORMAT:
    
    TOPICS: [comma-separated list from these options: #{Enum.join(@predefined_topics, ", ")}]
    
    SENTIMENT: [one of: #{Enum.join(@sentiment_categories, ", ")}]
    
    CONTENT_TYPE: [one of: #{Enum.join(@content_types, ", ")}]
    
    STRATEGIC_RELEVANCE: [one of: #{Enum.join(@strategic_relevance, ", ")}]
    
    KEY_INSIGHTS: [bullet points of 2-3 key takeaways]
    
    COMPETITIVE_IMPLICATIONS: [how this affects competitive landscape]
    
    FINANCIAL_IMPACT: [potential financial/market implications]
    
    ACTION_ITEMS: [recommended monitoring or response actions]
    
    Only use the predefined options provided. Be precise and analytical.
    """
  end
  
  defp build_trending_analysis_prompt(content_list, days_back) do
    content_summary = content_list
    |> Enum.take(50) # Limit for prompt size
    |> Enum.map(&"#{Map.get(&1, :title) || "No title"}: #{String.slice(Map.get(&1, :text) || "", 0, 100)}")
    |> Enum.join("\n")
    
    """
    TRENDING TOPIC ANALYSIS
    
    Analyze this content from the last #{days_back} days to identify trending topics:
    
    CONTENT SAMPLE:
    #{content_summary}
    
    IDENTIFY:
    1. Emerging themes/topics gaining momentum
    2. Topics with increasing mention frequency  
    3. New strategic developments
    4. Competitive pattern changes
    
    PROVIDE ANALYSIS IN THIS FORMAT:
    
    TRENDING_TOPICS: [topic name]: [trend direction: UP/DOWN/STABLE] - [significance: HIGH/MEDIUM/LOW]
    
    Example: AI Integration: UP - HIGH, ESG Concerns: DOWN - MEDIUM
    
    MARKET_SHIFTS: [key market/competitive shifts detected]
    
    STRATEGIC_OPPORTUNITIES: [opportunities these trends present]
    
    MONITORING_RECOMMENDATIONS: [what to watch closely]
    """
  end
  
  defp build_competitive_analysis_prompt(content, competitor_name) do
    """
    COMPETITIVE INTELLIGENCE ANALYSIS
    
    Analyze this content for competitive intelligence insights:
    
    COMPETITOR: #{competitor_name}
    CONTENT: #{Map.get(content, :title) || "No title"}
    TEXT: #{String.slice(Map.get(content, :text) || Map.get(content, :description) || "", 0, 800)}
    
    PROVIDE STRUCTURED ANALYSIS:
    
    THREAT_LEVEL: [HIGH/MEDIUM/LOW] - [explanation]
    
    STRATEGIC_MOVES: [key strategic moves or announcements]
    
    MARKET_POSITIONING: [how they're positioning themselves]
    
    COMPETITIVE_ADVANTAGES: [advantages they're claiming/demonstrating]
    
    OUR_RESPONSE_OPPORTUNITIES: [how AllianceBernstein could respond]
    
    INTELLIGENCE_VALUE: [why this matters for our strategy]
    
    FOLLOW_UP_MONITORING: [what to monitor next from this competitor]
    """
  end
  
  defp parse_tagging_response(response, original_content) do
    tags = %{
      topics: extract_field(response, "TOPICS") |> parse_topic_list(),
      sentiment: extract_field(response, "SENTIMENT"),
      content_type: extract_field(response, "CONTENT_TYPE"),
      strategic_relevance: extract_field(response, "STRATEGIC_RELEVANCE"),
      key_insights: extract_field(response, "KEY_INSIGHTS") |> parse_bullet_points(),
      competitive_implications: extract_field(response, "COMPETITIVE_IMPLICATIONS"),
      financial_impact: extract_field(response, "FINANCIAL_IMPACT"),
      action_items: extract_field(response, "ACTION_ITEMS") |> parse_bullet_points(),
      tagged_at: DateTime.utc_now()
    }
    
    Map.merge(original_content, %{tags: tags})
  end
  
  defp parse_trending_response(response) do
    %{
      trending_topics: extract_field(response, "TRENDING_TOPICS") |> parse_trending_topics(),
      market_shifts: extract_field(response, "MARKET_SHIFTS"),
      strategic_opportunities: extract_field(response, "STRATEGIC_OPPORTUNITIES"),
      monitoring_recommendations: extract_field(response, "MONITORING_RECOMMENDATIONS"),
      analyzed_at: DateTime.utc_now()
    }
  end
  
  defp parse_competitive_analysis(response) do
    %{
      threat_level: extract_field(response, "THREAT_LEVEL"),
      strategic_moves: extract_field(response, "STRATEGIC_MOVES"),
      market_positioning: extract_field(response, "MARKET_POSITIONING"),
      competitive_advantages: extract_field(response, "COMPETITIVE_ADVANTAGES"),
      response_opportunities: extract_field(response, "OUR_RESPONSE_OPPORTUNITIES"),
      intelligence_value: extract_field(response, "INTELLIGENCE_VALUE"),
      follow_up_monitoring: extract_field(response, "FOLLOW_UP_MONITORING"),
      analyzed_at: DateTime.utc_now()
    }
  end
  
  defp extract_field(text, field_name) do
    case Regex.run(~r/#{field_name}:\s*(.+?)(?=\n[A-Z_]+:|$)/s, text) do
      [_, content] -> String.trim(content)
      _ -> ""
    end
  end
  
  defp parse_topic_list(topics_string) do
    topics_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.filter(&(&1 in @predefined_topics))
  end
  
  defp parse_bullet_points(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, ["-", "•", "*"]))
    |> Enum.map(&String.replace(&1, ~r/^[-•*]\s*/, ""))
  end
  
  defp parse_trending_topics(trending_string) do
    trending_string
    |> String.split(",")
    |> Enum.map(&parse_trend_item/1)
    |> Enum.filter(& &1)
  end
  
  defp parse_trend_item(item) do
    case Regex.run(~r/(.+?):\s*(UP|DOWN|STABLE)\s*-\s*(HIGH|MEDIUM|LOW)/i, String.trim(item)) do
      [_, topic, direction, significance] -> 
        %{
          topic: String.trim(topic),
          direction: String.upcase(direction),
          significance: String.upcase(significance)
        }
      _ -> nil
    end
  end
  
  defp process_batch(batch) do
    Enum.map(batch, &tag_content/1)
  end
  
  defp default_tags(content) do
    Map.merge(content, %{
      tags: %{
        topics: [],
        sentiment: "Neutral",
        content_type: "Unknown",
        strategic_relevance: "Low",
        key_insights: [],
        competitive_implications: "Analysis unavailable",
        financial_impact: "Analysis unavailable", 
        action_items: [],
        tagged_at: DateTime.utc_now()
      }
    })
  end
  
  defp default_trending_topics do
    %{
      trending_topics: [],
      market_shifts: "Analysis unavailable",
      strategic_opportunities: "Analysis unavailable",
      monitoring_recommendations: "Analysis unavailable",
      analyzed_at: DateTime.utc_now()
    }
  end
  
  defp default_competitive_analysis do
    %{
      threat_level: "UNKNOWN",
      strategic_moves: "Analysis unavailable",
      market_positioning: "Analysis unavailable", 
      competitive_advantages: "Analysis unavailable",
      response_opportunities: "Analysis unavailable",
      intelligence_value: "Analysis unavailable",
      follow_up_monitoring: "Analysis unavailable",
      analyzed_at: DateTime.utc_now()
    }
  end
end