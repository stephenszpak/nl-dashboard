defmodule DashboardGen.Sentiment.SentimentAggregator do
  @moduledoc """
  Aggregates sentiment data and generates AI-powered insights.
  """
  
  alias DashboardGen.OpenAIClient
  require Logger
  
  @doc """
  Generates comprehensive sentiment insights from aggregated data.
  """
  def generate_insights(%{summary: summary, trend_data: trend_data, trending_topics: topics}) do
    prompt = build_insights_prompt(summary, trend_data, topics)
    
    case OpenAIClient.ask(prompt) do
      {:ok, response} -> 
        {:ok, %{
          insights: response,
          generated_at: DateTime.utc_now(),
          data_summary: summary
        }}
      {:error, reason} -> 
        Logger.warning("Failed to generate sentiment insights: #{reason}")
        {:ok, %{
          insights: generate_fallback_insights(summary, trend_data, topics),
          generated_at: DateTime.utc_now(),
          data_summary: summary
        }}
    end
  end
  
  @doc """
  Generates comparative analysis between companies.
  """
  def generate_competitive_sentiment_analysis(companies_data) do
    prompt = build_competitive_analysis_prompt(companies_data)
    
    case OpenAIClient.ask(prompt) do
      {:ok, response} -> 
        {:ok, %{
          analysis: response,
          companies: Enum.map(companies_data, & &1.company),
          generated_at: DateTime.utc_now()
        }}
      {:error, reason} ->
        Logger.warning("Failed to generate competitive sentiment analysis: #{reason}")
        {:ok, %{
          analysis: generate_fallback_competitive_analysis(companies_data),
          companies: Enum.map(companies_data, & &1.company),
          generated_at: DateTime.utc_now()
        }}
    end
  end
  
  @doc """
  Generates alert summaries for significant sentiment changes.
  """
  def generate_alert_summary(alerts) when is_list(alerts) do
    if length(alerts) == 0 do
      {:ok, %{summary: "No significant sentiment alerts detected.", alerts: []}}
    else
      prompt = build_alert_summary_prompt(alerts)
      
      case OpenAIClient.ask(prompt) do
        {:ok, response} -> 
          {:ok, %{
            summary: response,
            alerts: alerts,
            generated_at: DateTime.utc_now()
          }}
        {:error, reason} ->
          Logger.warning("Failed to generate alert summary: #{reason}")
          {:ok, %{
            summary: generate_fallback_alert_summary(alerts),
            alerts: alerts,
            generated_at: DateTime.utc_now()
          }}
      end
    end
  end
  
  ## Prompt Building Functions
  
  defp build_insights_prompt(summary, trend_data, topics) do
    # Format trend data for the prompt
    trend_summary = trend_data
    |> Enum.take(-7)  # Last 7 days
    |> Enum.map(fn day ->
      "#{day.date}: #{Float.round(day.avg_sentiment || 0, 2)} sentiment (#{day.total_mentions} mentions)"
    end)
    |> Enum.join("\n")
    
    topics_summary = topics
    |> Enum.take(5)
    |> Enum.map(fn topic ->
      "#{topic.topic}: #{topic.mentions} mentions (#{topic.avg_sentiment} avg sentiment)"
    end)
    |> Enum.join("\n")
    
    """
    Generate comprehensive sentiment insights for #{summary.company} based on the following data:
    
    ## Summary (Last #{summary.period_days} days)
    - Total mentions: #{summary.total_mentions}
    - Average sentiment: #{summary.average_sentiment}
    - Positive: #{summary.positive_percentage}%, Negative: #{summary.negative_percentage}%, Neutral: #{summary.neutral_percentage}%
    - Top sources: #{inspect(summary.top_sources)}
    
    ## Daily Trend (Last 7 days)
    #{trend_summary}
    
    ## Top Topics
    #{topics_summary}
    
    Please provide a detailed analysis including:
    
    1. **Overall Sentiment Health**: What does the current sentiment indicate about #{summary.company}?
    
    2. **Trend Analysis**: What patterns do you see in the daily sentiment trends? Are things improving or declining?
    
    3. **Key Topics & Themes**: What are people talking about most, and how does sentiment vary by topic?
    
    4. **Risk Assessment**: Are there any concerning trends or potential PR issues emerging?
    
    5. **Opportunities**: What positive sentiment can be leveraged, and what topics show promise?
    
    6. **Recommendations**: Specific actions to improve sentiment or address concerns.
    
    Format your response in clear sections with actionable insights. Focus on strategic implications and specific recommendations.
    """
  end
  
  defp build_competitive_analysis_prompt(companies_data) do
    companies_summary = companies_data
    |> Enum.map(fn company ->
      """
      **#{company.company}**:
      - Average sentiment: #{company.average_sentiment}
      - Total mentions: #{company.total_mentions}
      - Positive: #{company.positive_percentage}%, Negative: #{company.negative_percentage}%
      """
    end)
    |> Enum.join("\n\n")
    
    company_names = companies_data |> Enum.map(& &1.company) |> Enum.join(", ")
    
    """
    Analyze the competitive sentiment landscape for: #{company_names}
    
    ## Company Sentiment Data:
    #{companies_summary}
    
    Please provide a strategic analysis including:
    
    1. **Sentiment Leaders**: Which companies have the strongest positive sentiment and why?
    
    2. **Competitive Positioning**: How do companies compare in public perception?
    
    3. **Vulnerability Analysis**: Which companies show concerning sentiment patterns?
    
    4. **Market Opportunities**: What gaps or weaknesses can be exploited?
    
    5. **Strategic Recommendations**: How can companies improve their position relative to competitors?
    
    Focus on actionable competitive intelligence and strategic implications.
    """
  end
  
  defp build_alert_summary_prompt(alerts) do
    alerts_text = alerts
    |> Enum.map(fn alert ->
      case alert.type do
        :sentiment_drop ->
          "SENTIMENT DROP: #{alert.message} (#{alert.current_sentiment} vs #{alert.previous_sentiment})"
        :high_negative_volume ->
          "HIGH NEGATIVE VOLUME: #{alert.message} (#{alert.negative_percentage}% negative, #{alert.total_mentions} mentions)"
        _ ->
          "ALERT: #{alert.message}"
      end
    end)
    |> Enum.join("\n")
    
    """
    Summarize the following sentiment alerts and provide strategic guidance:
    
    #{alerts_text}
    
    Please provide:
    1. A concise summary of the situation
    2. Potential causes or context
    3. Immediate actions to take
    4. Risk assessment (low/medium/high)
    
    Keep the response focused and actionable.
    """
  end
  
  ## Fallback Functions
  
  defp generate_fallback_insights(summary, trend_data, topics) do
    sentiment_health = case summary.average_sentiment do
      score when score > 0.3 -> "Strong positive sentiment"
      score when score > 0.1 -> "Moderately positive sentiment"
      score when score > -0.1 -> "Neutral sentiment"
      score when score > -0.3 -> "Moderately negative sentiment"
      _ -> "Concerning negative sentiment"
    end
    
    risk_level = case {summary.negative_percentage, summary.total_mentions} do
      {neg, mentions} when neg > 60 and mentions > 50 -> "HIGH RISK"
      {neg, mentions} when neg > 40 and mentions > 20 -> "MEDIUM RISK"
      _ -> "LOW RISK"
    end
    
    top_topic = List.first(topics)
    topic_insight = if top_topic do
      "The most discussed topic is '#{top_topic.topic}' with #{top_topic.mentions} mentions and #{top_topic.avg_sentiment} average sentiment."
    else
      "No significant topics identified in recent mentions."
    end
    
    """
    ## Sentiment Analysis for #{summary.company}
    
    **Overall Health**: #{sentiment_health} (#{summary.average_sentiment} average score)
    
    **Risk Assessment**: #{risk_level} - #{summary.negative_percentage}% of #{summary.total_mentions} mentions are negative
    
    **Key Topics**: #{topic_insight}
    
    **Trend**: Based on #{length(trend_data)} days of data, monitoring recommended for sustained patterns.
    
    **Recommendations**: 
    - Monitor negative sentiment drivers closely
    - Engage with positive community feedback
    - Address concerns in trending topics
    """
  end
  
  defp generate_fallback_competitive_analysis(companies_data) do
    sorted_companies = Enum.sort_by(companies_data, & &1.average_sentiment, :desc)
    leader = List.first(sorted_companies)
    laggard = List.last(sorted_companies)
    
    """
    ## Competitive Sentiment Analysis
    
    **Sentiment Leader**: #{leader.company} (#{leader.average_sentiment} avg sentiment, #{leader.positive_percentage}% positive)
    
    **Needs Attention**: #{laggard.company} (#{laggard.average_sentiment} avg sentiment, #{laggard.negative_percentage}% negative)
    
    **Key Insights**:
    - #{length(companies_data)} companies analyzed
    - Sentiment spread from #{laggard.average_sentiment} to #{leader.average_sentiment}
    - Average mentions range: #{Enum.min_by(companies_data, & &1.total_mentions).total_mentions} to #{Enum.max_by(companies_data, & &1.total_mentions).total_mentions}
    
    **Recommendation**: Companies below 0.0 sentiment should prioritize reputation management initiatives.
    """
  end
  
  defp generate_fallback_alert_summary(alerts) do
    high_severity = Enum.count(alerts, & &1.severity == :high)
    medium_severity = Enum.count(alerts, & &1.severity == :medium)
    
    """
    ## Sentiment Alert Summary
    
    **Alert Count**: #{length(alerts)} total (#{high_severity} high severity, #{medium_severity} medium severity)
    
    **Action Required**: #{if high_severity > 0, do: "IMMEDIATE", else: "MONITOR"}
    
    **Key Issues**:
    #{Enum.map(alerts, & "- #{&1.message}") |> Enum.join("\n")}
    
    **Recommendation**: #{if high_severity > 0, do: "Address high-severity alerts immediately to prevent reputation damage.", else: "Continue monitoring sentiment trends and be prepared to respond if patterns worsen."}
    """
  end
end