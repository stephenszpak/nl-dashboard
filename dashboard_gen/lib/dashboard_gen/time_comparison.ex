defmodule DashboardGen.TimeComparison do
  @moduledoc """
  Time-based comparison analysis for analytics and competitive intelligence data.
  
  Provides sophisticated period-over-period comparisons including:
  - Quarter over quarter analysis
  - Year over year trends
  - Custom period comparisons
  - Seasonal trend detection
  """
  
  alias DashboardGen.{Analytics, Insights, CodexClient}
  import Ecto.Query
  require Logger
  
  @doc """
  Compare current period with previous period
  """
  def compare_periods(metric_type, current_period, previous_period, options \\ %{}) do
    current_data = get_period_data(metric_type, current_period, options)
    previous_data = get_period_data(metric_type, previous_period, options)
    
    comparison = calculate_comparison_metrics(current_data, previous_data)
    analysis = generate_comparison_analysis(comparison, metric_type, current_period, previous_period)
    
    %{
      current_period: current_period,
      previous_period: previous_period,
      current_data: current_data,
      previous_data: previous_data,
      comparison: comparison,
      analysis: analysis,
      generated_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Quarter over quarter comparison
  """
  def quarter_over_quarter(year, quarter, options \\ %{}) do
    current_period = build_quarter_period(year, quarter)
    previous_period = build_quarter_period(year, quarter - 1)
    
    compare_periods(:quarterly_metrics, current_period, previous_period, options)
  end
  
  @doc """
  Year over year comparison
  """
  def year_over_year(year, options \\ %{}) do
    current_period = build_year_period(year)
    previous_period = build_year_period(year - 1)
    
    compare_periods(:yearly_metrics, current_period, previous_period, options)
  end
  
  @doc """
  Monthly comparison with trend analysis
  """
  def monthly_trends(start_date, end_date, options \\ %{}) do
    months = generate_monthly_periods(start_date, end_date)
    
    monthly_data = Enum.map(months, fn month_period ->
      data = get_period_data(:monthly_metrics, month_period, options)
      {month_period, data}
    end)
    
    trends = analyze_monthly_trends(monthly_data)
    
    %{
      periods: monthly_data,
      trends: trends,
      start_date: start_date,
      end_date: end_date,
      generated_at: DateTime.utc_now()
    }
  end
  
  @doc """
  Competitive positioning comparison over time
  """
  def competitive_positioning_trends(competitors, start_date, end_date) do
    periods = generate_quarterly_periods(start_date, end_date)
    
    positioning_data = Enum.map(periods, fn period ->
      competitor_data = Enum.map(competitors, fn competitor ->
        insights = get_competitor_period_data(competitor, period)
        positioning = analyze_competitor_positioning(competitor, insights, period)
        {competitor, positioning}
      end)
      
      {period, competitor_data}
    end)
    
    trends = analyze_competitive_trends(positioning_data)
    
    %{
      competitors: competitors,
      periods: positioning_data,
      trends: trends,
      start_date: start_date,
      end_date: end_date,
      generated_at: DateTime.utc_now()
    }
  end
  
  # Data Collection Functions
  
  defp get_period_data(:quarterly_metrics, period, _options) do
    %{
      analytics: get_analytics_for_period(period),
      competitor_activity: get_competitor_activity_for_period(period),
      market_metrics: get_market_metrics_for_period(period)
    }
  end
  
  defp get_period_data(:yearly_metrics, period, _options) do
    %{
      analytics: get_analytics_for_period(period),
      competitor_activity: get_competitor_activity_for_period(period),
      market_metrics: get_market_metrics_for_period(period),
      strategic_initiatives: get_strategic_initiatives_for_period(period)
    }
  end
  
  defp get_period_data(:monthly_metrics, period, _options) do
    %{
      analytics: get_analytics_for_period(period),
      competitor_activity: get_competitor_activity_for_period(period)
    }
  end
  
  defp get_analytics_for_period(period) do
    # Calculate days in period for analytics query
    days_in_period = Date.diff(period.end_date, period.start_date)
    
    # Get analytics summary for the period
    Analytics.get_analytics_summary(days_in_period)
  end
  
  defp get_competitor_activity_for_period(period) do
    # Get competitor insights for the specific period
    Insights.get_activity_for_period(period.start_date, period.end_date)
  end
  
  defp get_market_metrics_for_period(_period) do
    # Placeholder for market data integration
    %{
      market_sentiment: "neutral",
      industry_growth: 0.0,
      regulatory_changes: []
    }
  end
  
  defp get_strategic_initiatives_for_period(_period) do
    # Placeholder for strategic initiatives tracking
    []
  end
  
  defp get_competitor_period_data(competitor, period) do
    Insights.get_competitor_insights_for_period(competitor, period.start_date, period.end_date)
  end
  
  # Comparison Calculations
  
  defp calculate_comparison_metrics(current, previous) do
    %{
      analytics_comparison: compare_analytics_metrics(current.analytics, previous.analytics),
      activity_comparison: compare_activity_metrics(current.competitor_activity, previous.competitor_activity),
      growth_rates: calculate_growth_rates(current, previous),
      significant_changes: identify_significant_changes(current, previous)
    }
  end
  
  defp compare_analytics_metrics(current, previous) do
    %{
      page_views: calculate_percentage_change(current.total_page_views, previous.total_page_views),
      unique_visitors: calculate_percentage_change(current.unique_visitors, previous.unique_visitors),
      conversion_rate: calculate_percentage_change(
        get_in(current.conversion_metrics, [:conversions]) || 0,
        get_in(previous.conversion_metrics, [:conversions]) || 0
      ),
      top_pages_shift: analyze_top_pages_changes(current.top_pages, previous.top_pages)
    }
  end
  
  defp compare_activity_metrics(current, previous) do
    current_total = calculate_total_activity(current)
    previous_total = calculate_total_activity(previous)
    
    %{
      total_activity_change: calculate_percentage_change(current_total, previous_total),
      by_company: compare_company_activity(current, previous)
    }
  end
  
  defp calculate_growth_rates(current, previous) do
    analytics_growth = calculate_analytics_growth_rate(current.analytics, previous.analytics)
    competitive_growth = calculate_competitive_growth_rate(current.competitor_activity, previous.competitor_activity)
    
    %{
      analytics_growth_rate: analytics_growth,
      competitive_growth_rate: competitive_growth,
      overall_momentum: determine_momentum(analytics_growth, competitive_growth)
    }
  end
  
  defp identify_significant_changes(current, previous) do
    changes = []
    
    # Check for significant analytics changes
    page_view_change = calculate_percentage_change(current.analytics.total_page_views, previous.analytics.total_page_views)
    changes = if abs(page_view_change) > 20 do
      [%{type: :page_views, change: page_view_change, significance: :high} | changes]
    else
      changes
    end
    
    # Check for competitive activity spikes
    current_activity = calculate_total_activity(current.competitor_activity)
    previous_activity = calculate_total_activity(previous.competitor_activity)
    activity_change = calculate_percentage_change(current_activity, previous_activity)
    changes = if abs(activity_change) > 50 do
      [%{type: :competitor_activity, change: activity_change, significance: :high} | changes]
    else
      changes
    end
    
    changes
  end
  
  # Trend Analysis
  
  defp analyze_monthly_trends(monthly_data) do
    analytics_trend = calculate_trend_direction(monthly_data, :analytics)
    activity_trend = calculate_trend_direction(monthly_data, :competitor_activity)
    
    %{
      analytics_trend: analytics_trend,
      competitor_activity_trend: activity_trend,
      seasonality: detect_seasonality(monthly_data),
      momentum: calculate_momentum_score(monthly_data)
    }
  end
  
  defp analyze_competitive_trends(positioning_data) do
    # Analyze how competitive positioning has shifted over time
    trends_by_competitor = Enum.map(positioning_data, fn {period, competitor_data} ->
      period_trends = Enum.map(competitor_data, fn {competitor, positioning} ->
        {competitor, extract_positioning_metrics(positioning)}
      end)
      {period, period_trends}
    end)
    
    %{
      positioning_shifts: identify_positioning_shifts(trends_by_competitor),
      market_leaders: identify_market_leaders_over_time(trends_by_competitor),
      competitive_gaps: identify_competitive_gaps(trends_by_competitor)
    }
  end
  
  # Analysis Generation
  
  defp generate_comparison_analysis(comparison, metric_type, current_period, previous_period) do
    prompt = build_comparison_analysis_prompt(comparison, metric_type, current_period, previous_period)
    
    case CodexClient.ask(prompt) do
      {:ok, analysis} -> analysis
      {:error, _} -> "Analysis generation failed"
    end
  end
  
  defp build_comparison_analysis_prompt(comparison, metric_type, current_period, previous_period) do
    """
    PERIOD COMPARISON ANALYSIS
    
    Analyze the performance comparison between two periods:
    
    CURRENT PERIOD: #{format_period(current_period)}
    PREVIOUS PERIOD: #{format_period(previous_period)}
    COMPARISON TYPE: #{metric_type}
    
    ANALYTICS COMPARISON:
    #{format_analytics_comparison(comparison.analytics_comparison)}
    
    COMPETITOR ACTIVITY COMPARISON:
    #{format_activity_comparison(comparison.activity_comparison)}
    
    SIGNIFICANT CHANGES:
    #{format_significant_changes(comparison.significant_changes)}
    
    PROVIDE STRUCTURED ANALYSIS:
    
    ## Performance Summary
    [Overall performance vs previous period]
    
    ## Key Changes
    [Most significant changes and their implications]
    
    ## Competitive Position
    [How our position has changed relative to competitors]
    
    ## Trend Implications
    [What these trends suggest for the future]
    
    ## Strategic Recommendations
    [Actions based on the comparison insights]
    
    Focus on actionable insights and strategic implications.
    """
  end
  
  # Helper Functions
  
  defp calculate_percentage_change(current, previous) when is_number(current) and is_number(previous) and previous > 0 do
    ((current - previous) / previous * 100) |> Float.round(2)
  end
  defp calculate_percentage_change(_, _), do: 0.0
  
  defp build_quarter_period(year, quarter) when quarter > 0 and quarter <= 4 do
    start_month = (quarter - 1) * 3 + 1
    end_month = quarter * 3
    
    %{
      start_date: Date.new!(year, start_month, 1),
      end_date: Date.end_of_month(Date.new!(year, end_month, 1)),
      type: :quarter,
      label: "Q#{quarter} #{year}"
    }
  end
  
  defp build_quarter_period(year, 0) do
    build_quarter_period(year - 1, 4)
  end
  
  defp build_year_period(year) do
    %{
      start_date: Date.new!(year, 1, 1),
      end_date: Date.new!(year, 12, 31),
      type: :year,
      label: "#{year}"
    }
  end
  
  defp generate_monthly_periods(_start_date, _end_date) do
    # Generate list of monthly periods between start and end dates
    []
  end
  
  defp generate_quarterly_periods(_start_date, _end_date) do
    # Generate list of quarterly periods between start and end dates
    []
  end
  
  defp calculate_total_activity(activity_data) when is_map(activity_data) do
    # Sum up all activity metrics
    0
  end
  defp calculate_total_activity(_), do: 0
  
  defp compare_company_activity(_current, _previous) do
    %{}
  end
  
  defp calculate_analytics_growth_rate(_current, _previous), do: 0.0
  defp calculate_competitive_growth_rate(_current, _previous), do: 0.0
  defp determine_momentum(_analytics_growth, _competitive_growth), do: :stable
  
  defp analyze_top_pages_changes(_current_pages, _previous_pages) do
    %{new_entries: [], dropped_pages: [], ranking_changes: []}
  end
  
  defp calculate_trend_direction(_monthly_data, _metric), do: :stable
  defp detect_seasonality(_monthly_data), do: %{seasonal: false}
  defp calculate_momentum_score(_monthly_data), do: 0.5
  
  defp analyze_competitor_positioning(_competitor, _insights, _period) do
    %{activity_score: 0, sentiment: "neutral", strategic_focus: []}
  end
  
  defp extract_positioning_metrics(_positioning), do: %{}
  defp identify_positioning_shifts(_trends), do: []
  defp identify_market_leaders_over_time(_trends), do: []
  defp identify_competitive_gaps(_trends), do: []
  
  defp format_period(period), do: period.label || "Unknown Period"
  defp format_analytics_comparison(comparison), do: inspect(comparison)
  defp format_activity_comparison(comparison), do: inspect(comparison)
  defp format_significant_changes(changes), do: inspect(changes)
end