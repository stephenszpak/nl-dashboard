defmodule DashboardGen.PlanningAgents do
  @moduledoc """
  Scheduled planning agents that automatically generate strategic reports and briefs.
  
  Includes weekly marketing briefs, competitive intelligence summaries,
  and proactive strategic recommendations.
  """
  
  use GenServer
  alias DashboardGen.{CodexClient, Insights, Analytics, AgentTagging}
  require Logger
  
  @check_interval :timer.minutes(30) # Check every 30 minutes for scheduled tasks
  
  # Planning schedules
  @monday_marketing_brief %{day: 1, hour: 9, minute: 0} # Monday 9:00 AM
  @weekly_competitive_summary %{day: 5, hour: 17, minute: 0} # Friday 5:00 PM  
  @monthly_trend_analysis %{day_of_month: 1, hour: 10, minute: 0} # 1st of month 10:00 AM
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_check()
    {:ok, %{last_check: DateTime.utc_now(), generated_reports: %{}}}
  end
  
  def handle_info(:check_schedules, state) do
    new_state = check_and_execute_schedules(state)
    schedule_check()
    {:noreply, new_state}
  end
  
  @doc """
  Manually trigger a marketing brief
  """
  def generate_marketing_brief do
    GenServer.cast(__MODULE__, :generate_marketing_brief)
  end
  
  @doc """
  Manually trigger competitive summary
  """
  def generate_competitive_summary do
    GenServer.cast(__MODULE__, :generate_competitive_summary)
  end
  
  def handle_cast(:generate_marketing_brief, state) do
    Task.start(fn -> execute_marketing_brief() end)
    {:noreply, state}
  end
  
  def handle_cast(:generate_competitive_summary, state) do
    Task.start(fn -> execute_competitive_summary() end)
    {:noreply, state}
  end
  
  defp schedule_check do
    Process.send_after(self(), :check_schedules, @check_interval)
  end
  
  defp check_and_execute_schedules(state) do
    now = DateTime.utc_now()
    
    new_state = state
    |> check_monday_marketing_brief(now)
    |> check_weekly_competitive_summary(now)
    |> check_monthly_trend_analysis(now)
    
    %{new_state | last_check: now}
  end
  
  defp check_monday_marketing_brief(state, now) do
    if should_run_scheduled_task?(now, @monday_marketing_brief, state, :marketing_brief) do
      Logger.info("Starting scheduled Monday marketing brief")
      Task.start(fn -> execute_marketing_brief() end)
      mark_task_completed(state, :marketing_brief, now)
    else
      state
    end
  end
  
  defp check_weekly_competitive_summary(state, now) do
    if should_run_scheduled_task?(now, @weekly_competitive_summary, state, :competitive_summary) do
      Logger.info("Starting scheduled weekly competitive summary")
      Task.start(fn -> execute_competitive_summary() end)
      mark_task_completed(state, :competitive_summary, now)
    else
      state
    end
  end
  
  defp check_monthly_trend_analysis(state, now) do
    if should_run_scheduled_task?(now, @monthly_trend_analysis, state, :trend_analysis) do
      Logger.info("Starting scheduled monthly trend analysis")
      Task.start(fn -> execute_trend_analysis() end)
      mark_task_completed(state, :trend_analysis, now)
    else
      state
    end
  end
  
  defp should_run_scheduled_task?(now, schedule, state, task_key) do
    matches_schedule?(now, schedule) and not already_completed_today?(state, task_key, now)
  end
  
  defp matches_schedule?(now, %{day: day, hour: hour, minute: minute}) do
    # Weekly schedule (day of week)
    Date.day_of_week(now) == day and 
    now.hour == hour and 
    now.minute >= minute and 
    now.minute < minute + 30 # 30-minute window
  end
  
  defp matches_schedule?(now, %{day_of_month: day, hour: hour, minute: minute}) do
    # Monthly schedule
    now.day == day and 
    now.hour == hour and 
    now.minute >= minute and 
    now.minute < minute + 30
  end
  
  defp already_completed_today?(state, task_key, now) do
    case Map.get(state.generated_reports, task_key) do
      nil -> false
      last_run -> Date.compare(DateTime.to_date(last_run), DateTime.to_date(now)) == :eq
    end
  end
  
  defp mark_task_completed(state, task_key, timestamp) do
    %{state | generated_reports: Map.put(state.generated_reports, task_key, timestamp)}
  end
  
  # Planning Agent Executors
  
  defp execute_marketing_brief do
    Logger.info("Generating Monday Marketing Brief...")
    
    # Gather data from last week
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -7 * 86400, :second)
    
    # Get analytics data
    analytics_summary = Analytics.get_analytics_summary(7)
    
    # Get competitor activity
    competitor_activity = Insights.get_weekly_activity_summary(start_date, end_date)
    
    # Get trending topics
    recent_content = Insights.get_recent_content_for_analysis(start_date, end_date)
    trending_analysis = AgentTagging.detect_trending_topics(recent_content, 7)
    
    # Generate comprehensive brief
    prompt = build_marketing_brief_prompt(analytics_summary, competitor_activity, trending_analysis)
    
    case CodexClient.ask(prompt) do
      {:ok, brief} ->
        store_generated_report(:marketing_brief, brief, %{
          analytics: analytics_summary,
          competitors: competitor_activity, 
          trends: trending_analysis
        })
        Logger.info("Monday Marketing Brief generated successfully")
        
      {:error, reason} ->
        Logger.error("Failed to generate marketing brief: #{reason}")
    end
  end
  
  defp execute_competitive_summary do
    Logger.info("Generating Weekly Competitive Summary...")
    
    # Get competitor insights from last week
    insights_summary = Insights.get_competitive_summary(7)
    
    # Get tagged competitive intelligence
    competitive_content = Insights.get_recent_content_by_type("competitive", 7)
    
    prompt = build_competitive_summary_prompt(insights_summary, competitive_content)
    
    case CodexClient.ask(prompt) do
      {:ok, summary} ->
        store_generated_report(:competitive_summary, summary, insights_summary)
        Logger.info("Weekly Competitive Summary generated successfully")
        
      {:error, reason} ->
        Logger.error("Failed to generate competitive summary: #{reason}")
    end
  end
  
  defp execute_trend_analysis do
    Logger.info("Generating Monthly Trend Analysis...")
    
    # Get last 30 days of data
    content = Insights.get_recent_content_for_analysis(DateTime.add(DateTime.utc_now(), -30 * 86400, :second), DateTime.utc_now())
    trends = AgentTagging.detect_trending_topics(content, 30)
    
    prompt = build_trend_analysis_prompt(trends, content)
    
    case CodexClient.ask(prompt) do
      {:ok, analysis} ->
        store_generated_report(:trend_analysis, analysis, trends)
        Logger.info("Monthly Trend Analysis generated successfully")
        
      {:error, reason} ->
        Logger.error("Failed to generate trend analysis: #{reason}")
    end
  end
  
  # Prompt Builders
  
  defp build_marketing_brief_prompt(analytics, competitors, trends) do
    """
    WEEKLY MARKETING INTELLIGENCE BRIEF
    
    Generate a comprehensive marketing brief for AllianceBernstein leadership covering the past week.
    
    ANALYTICS PERFORMANCE:
    - Total Page Views: #{analytics.total_page_views}
    - Unique Visitors: #{analytics.unique_visitors}
    - Top Pages: #{format_top_pages(analytics.top_pages)}
    - Geographic Distribution: #{format_geography(analytics.geographic_breakdown)}
    
    COMPETITOR ACTIVITY:
    #{format_competitor_activity(competitors)}
    
    TRENDING TOPICS:
    #{format_trending_topics(trends)}
    
    PROVIDE A STRUCTURED BRIEF WITH:
    
    ## Executive Summary
    [2-3 sentence overview of key developments]
    
    ## Performance Highlights
    [Key analytics insights and performance metrics]
    
    ## Competitive Landscape
    [Major competitor moves and implications]
    
    ## Market Trends & Opportunities
    [Trending topics and strategic opportunities]
    
    ## Strategic Recommendations
    [3-5 specific, actionable recommendations]
    
    ## Week Ahead Monitoring
    [What to watch for in the coming week]
    
    Keep sections concise but strategic. Focus on actionable insights.
    """
  end
  
  defp build_competitive_summary_prompt(insights, content) do
    """
    WEEKLY COMPETITIVE INTELLIGENCE SUMMARY
    
    Analyze competitive landscape changes and strategic implications.
    
    COMPETITOR INSIGHTS:
    #{format_insights_summary(insights)}
    
    COMPETITIVE CONTENT ANALYSIS:
    #{format_competitive_content(content)}
    
    PROVIDE STRUCTURED ANALYSIS:
    
    ## Competitive Threats
    [New threats or aggressive moves]
    
    ## Market Positioning Changes
    [How competitors are repositioning]
    
    ## Strategic Opportunities
    [Gaps or opportunities identified]
    
    ## Intelligence Priorities
    [What to monitor closely next week]
    
    ## Recommended Responses
    [Strategic responses AllianceBernstein should consider]
    """
  end
  
  defp build_trend_analysis_prompt(trends, content) do
    """
    MONTHLY MARKET TREND ANALYSIS
    
    Comprehensive analysis of market trends and strategic implications.
    
    TRENDING TOPICS:
    #{format_trending_analysis(trends)}
    
    CONTENT VOLUME: #{length(content)} pieces analyzed
    
    PROVIDE COMPREHENSIVE ANALYSIS:
    
    ## Emerging Trends
    [New trends gaining momentum]
    
    ## Declining Themes  
    [Topics losing relevance]
    
    ## Strategic Implications
    [How trends affect financial services]
    
    ## AllianceBernstein Positioning
    [How we're positioned relative to trends]
    
    ## Strategic Recommendations
    [Product, marketing, and positioning recommendations]
    
    ## Next Month Outlook
    [Trends to watch and prepare for]
    """
  end
  
  # Formatters
  defp format_top_pages(pages) do
    pages |> Enum.take(5) |> Enum.map(&"#{&1.page} (#{&1.views} views)") |> Enum.join(", ")
  end
  
  defp format_geography(geo) do
    geo |> Enum.take(3) |> Enum.map(&"#{&1.country} (#{&1.visitors})") |> Enum.join(", ")
  end
  
  defp format_competitor_activity(_competitors) do
    # Format competitor activity data
    "Competitor activity analysis would go here"
  end
  
  defp format_trending_topics(trends) do
    case trends.trending_topics do
      [] -> "No significant trends detected"
      topics -> Enum.map(topics, &"#{&1.topic}: #{&1.direction} (#{&1.significance})") |> Enum.join("\n")
    end
  end
  
  defp format_insights_summary(_insights) do
    "Insights summary formatting would go here"
  end
  
  defp format_competitive_content(_content) do
    "Competitive content analysis would go here"
  end
  
  defp format_trending_analysis(trends) do
    format_trending_topics(trends)
  end
  
  defp store_generated_report(type, content, metadata) do
    report = %{
      type: type,
      content: content,
      metadata: metadata,
      generated_at: DateTime.utc_now(),
      id: generate_report_id()
    }
    
    # Store in alert system for dashboard display
    DashboardGen.AlertStore.store_alert(%{
      id: report.id,
      type: :scheduled_report,
      severity: :info,
      title: format_report_title(type),
      message: "Scheduled #{format_report_title(type)} has been generated",
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      metadata: report
    })
    
    Logger.info("Stored #{type} report: #{report.id}")
  end
  
  defp format_report_title(:marketing_brief), do: "Monday Marketing Brief"
  defp format_report_title(:competitive_summary), do: "Weekly Competitive Summary"
  defp format_report_title(:trend_analysis), do: "Monthly Trend Analysis"
  
  defp generate_report_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end