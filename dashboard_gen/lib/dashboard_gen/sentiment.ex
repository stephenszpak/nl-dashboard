defmodule DashboardGen.Sentiment do
  @moduledoc """
  The Sentiment context - handles sentiment analysis data and insights.
  """
  
  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Sentiment.{SentimentData, SentimentAnalyzer, SentimentAggregator}
  
  ## Sentiment Data CRUD
  
  @doc """
  Creates sentiment data from analysis.
  """
  def create_sentiment_data(attrs) do
    attrs
    |> SentimentData.analysis_changeset()
    |> Repo.insert()
  end
  
  @doc """
  Gets sentiment data by ID.
  """
  def get_sentiment_data!(id) do
    Repo.get!(SentimentData, id)
  end
  
  @doc """
  Lists sentiment data with filters.
  """
  def list_sentiment_data(opts \\ []) do
    company = Keyword.get(opts, :company)
    source = Keyword.get(opts, :source)
    sentiment_label = Keyword.get(opts, :sentiment_label)
    days_back = Keyword.get(opts, :days_back, 30)
    limit = Keyword.get(opts, :limit, 100)
    
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    query = from s in SentimentData,
      where: s.inserted_at >= ^cutoff_date and s.is_valid == true,
      order_by: [desc: s.inserted_at],
      limit: ^limit
    
    query = if company, do: from(s in query, where: s.company == ^company), else: query
    query = if source, do: from(s in query, where: s.source == ^source), else: query
    query = if sentiment_label, do: from(s in query, where: s.sentiment_label == ^sentiment_label), else: query
    
    Repo.all(query)
  end
  
  ## Analytics and Aggregations
  
  @doc """
  Gets sentiment summary for a company over time period.
  """
  def get_sentiment_summary(company, days_back \\ 7) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    # Get basic metrics
    base_query = from s in SentimentData,
      where: s.company == ^company and s.inserted_at >= ^cutoff_date and s.is_valid == true
    
    total_count = Repo.aggregate(base_query, :count)
    avg_score = Repo.aggregate(base_query, :avg, :sentiment_score) || 0.0
    
    # Get sentiment breakdown
    sentiment_breakdown = 
      from(s in base_query,
        group_by: s.sentiment_label,
        select: {s.sentiment_label, count(s.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})
    
    # Get top sources
    top_sources = 
      from(s in base_query,
        group_by: s.source,
        select: {s.source, count(s.id)},
        order_by: [desc: count(s.id)],
        limit: 5
      )
      |> Repo.all()
    
    %{
      company: company,
      period_days: days_back,
      total_mentions: total_count,
      average_sentiment: Float.round(avg_score, 3),
      sentiment_breakdown: sentiment_breakdown,
      top_sources: top_sources,
      positive_percentage: calculate_percentage(sentiment_breakdown, "positive", total_count),
      negative_percentage: calculate_percentage(sentiment_breakdown, "negative", total_count),
      neutral_percentage: calculate_percentage(sentiment_breakdown, "neutral", total_count)
    }
  end
  
  @doc """
  Gets daily sentiment trend for a company.
  """
  def get_daily_sentiment_trend(company, days_back \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    query = 
      from(s in SentimentData,
        where: s.company == ^company and s.inserted_at >= ^cutoff_date and s.is_valid == true,
        group_by: [fragment("DATE(?)", s.inserted_at)],
        select: %{
          date: fragment("DATE(?)", s.inserted_at),
          avg_sentiment: avg(s.sentiment_score),
          total_mentions: count(s.id),
          positive_count: sum(fragment("CASE WHEN ? = 'positive' THEN 1 ELSE 0 END", s.sentiment_label)),
          negative_count: sum(fragment("CASE WHEN ? = 'negative' THEN 1 ELSE 0 END", s.sentiment_label)),
          neutral_count: sum(fragment("CASE WHEN ? = 'neutral' THEN 1 ELSE 0 END", s.sentiment_label))
        },
        order_by: [asc: fragment("DATE(?)", s.inserted_at)]
      )
    
    Repo.all(query)
  end
  
  @doc """
  Compares sentiment between companies.
  """
  def compare_company_sentiment(companies, days_back \\ 7) when is_list(companies) do
    Enum.map(companies, fn company ->
      summary = get_sentiment_summary(company, days_back)
      Map.put(summary, :company, company)
    end)
  end
  
  @doc """
  Gets trending topics for a company based on recent sentiment data.
  """
  def get_trending_topics(company, days_back \\ 7) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    # Get all topics from recent sentiment data
    topics_data = 
      from(s in SentimentData,
        where: s.company == ^company and s.inserted_at >= ^cutoff_date and s.is_valid == true,
        select: {s.topics, s.sentiment_score}
      )
      |> Repo.all()
    
    # Flatten and count topics with sentiment
    topics_data
    |> Enum.flat_map(fn {topics, score} -> 
      Enum.map(topics, fn topic -> {topic, score} end)
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {topic, scores} ->
      sentiment_scores = Enum.map(scores, &elem(&1, 1))
      %{
        topic: topic,
        mentions: length(sentiment_scores),
        avg_sentiment: Float.round(Enum.sum(sentiment_scores) / length(sentiment_scores), 3)
      }
    end)
    |> Enum.sort_by(& &1.mentions, :desc)
    |> Enum.take(10)
  end
  
  @doc """
  Analyzes sentiment for text content using AI.
  """
  def analyze_sentiment(content, opts \\ []) do
    SentimentAnalyzer.analyze_text(content, opts)
  end
  
  @doc """
  Generates AI-powered sentiment insights.
  """
  def generate_sentiment_insights(company, days_back \\ 7) do
    summary = get_sentiment_summary(company, days_back)
    trend_data = get_daily_sentiment_trend(company, days_back)
    trending_topics = get_trending_topics(company, days_back)
    
    SentimentAggregator.generate_insights(%{
      summary: summary,
      trend_data: trend_data,
      trending_topics: trending_topics
    })
  end
  
  @doc """
  Detects sentiment alerts (significant changes or negative spikes).
  """
  def detect_sentiment_alerts(company) do
    current_summary = get_sentiment_summary(company, 1)  # Last 24 hours
    previous_summary = get_sentiment_summary(company, 2) # Previous 24 hours
    
    alerts = []
    
    # Check for significant sentiment drop
    current_avg = current_summary.average_sentiment
    previous_avg = previous_summary.average_sentiment
    
    alerts = if previous_avg > 0 and current_avg < previous_avg - 0.3 do
      [%{
        type: :sentiment_drop,
        severity: :high,
        message: "Significant sentiment drop detected for #{company}",
        current_sentiment: current_avg,
        previous_sentiment: previous_avg,
        change: Float.round(current_avg - previous_avg, 3)
      } | alerts]
    else
      alerts
    end
    
    # Check for high negative volume
    negative_percentage = current_summary.negative_percentage
    alerts = if negative_percentage > 50 and current_summary.total_mentions > 10 do
      [%{
        type: :high_negative_volume,
        severity: :medium,
        message: "High volume of negative sentiment detected for #{company}",
        negative_percentage: negative_percentage,
        total_mentions: current_summary.total_mentions
      } | alerts]
    else
      alerts
    end
    
    alerts
  end
  
  ## Helper functions
  
  defp calculate_percentage(breakdown, label, total) do
    count = Map.get(breakdown, label, 0)
    if total > 0, do: Float.round(count / total * 100, 1), else: 0.0
  end
end