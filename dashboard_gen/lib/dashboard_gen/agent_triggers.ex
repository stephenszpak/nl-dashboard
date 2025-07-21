defmodule DashboardGen.AgentTriggers do
  @moduledoc """
  Automatic trigger system for detecting data patterns and anomalies.
  
  Monitors analytics data, competitor activity, and market changes to automatically
  trigger notifications and actions when significant events occur.
  """
  
  use GenServer
  alias DashboardGen.{Analytics, Insights, CodexClient}
  alias DashboardGen.Notifications
  require Logger
  
  @check_interval :timer.minutes(15) # Check every 15 minutes
  @spike_threshold 2.0 # 200% increase considered a spike
  @significant_change_threshold 0.3 # 30% change considered significant
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_check()
    {:ok, %{last_check: DateTime.utc_now(), baselines: %{}}}
  end
  
  def handle_info(:check_triggers, state) do
    new_state = check_all_triggers(state)
    schedule_check()
    {:noreply, new_state}
  end
  
  defp schedule_check do
    Process.send_after(self(), :check_triggers, @check_interval)
  end
  
  defp check_all_triggers(state) do
    Logger.info("Running agent trigger checks...")
    
    new_state = state
    |> check_analytics_spikes()
    |> check_competitor_activity()
    |> check_market_changes()
    |> Map.put(:last_check, DateTime.utc_now())
    
    new_state
  end
  
  @doc """
  Check for analytics data spikes (traffic, conversions, etc.)
  """
  defp check_analytics_spikes(state) do
    current_metrics = get_current_analytics_metrics()
    baseline_metrics = Map.get(state.baselines, :analytics, current_metrics)
    
    # Check for traffic spikes
    if spike_detected?(current_metrics.page_views, baseline_metrics.page_views) do
      trigger_notification(%{
        type: :analytics_spike,
        metric: "page_views",
        current: current_metrics.page_views,
        baseline: baseline_metrics.page_views,
        change_percent: calculate_change_percent(current_metrics.page_views, baseline_metrics.page_views)
      })
    end
    
    # Check for conversion spikes
    if spike_detected?(current_metrics.conversions, baseline_metrics.conversions) do
      trigger_notification(%{
        type: :analytics_spike,
        metric: "conversions", 
        current: current_metrics.conversions,
        baseline: baseline_metrics.conversions,
        change_percent: calculate_change_percent(current_metrics.conversions, baseline_metrics.conversions)
      })
    end
    
    # Update baseline (rolling average)
    new_baseline = %{
      page_views: (baseline_metrics.page_views * 0.7 + current_metrics.page_views * 0.3),
      conversions: (baseline_metrics.conversions * 0.7 + current_metrics.conversions * 0.3)
    }
    
    put_in(state.baselines[:analytics], new_baseline)
  end
  
  @doc """
  Check for unusual competitor activity
  """
  defp check_competitor_activity(state) do
    recent_activity = Insights.get_recent_activity_summary(hours: 6)
    baseline_activity = Map.get(state.baselines, :competitor_activity, recent_activity)
    
    Enum.each(recent_activity, fn {company, activity} ->
      baseline = Map.get(baseline_activity, company, activity)
      
      # Check for press release spikes
      if spike_detected?(activity.press_releases, baseline.press_releases) do
        trigger_notification(%{
          type: :competitor_spike,
          company: company,
          metric: "press_releases",
          current: activity.press_releases,
          baseline: baseline.press_releases,
          recent_titles: get_recent_titles(company, :press_releases, 3)
        })
      end
      
      # Check for social media spikes  
      if spike_detected?(activity.social_posts, baseline.social_posts) do
        trigger_notification(%{
          type: :competitor_spike,
          company: company,
          metric: "social_posts", 
          current: activity.social_posts,
          baseline: baseline.social_posts,
          recent_titles: get_recent_titles(company, :social_media, 3)
        })
      end
    end)
    
    # Update baseline
    new_baseline = merge_activity_baselines(baseline_activity, recent_activity)
    put_in(state.baselines[:competitor_activity], new_baseline)
  end
  
  @doc """
  Check for significant market/trend changes
  """
  defp check_market_changes(state) do
    # Check for keyword trend changes
    trend_changes = detect_trending_topics()
    
    Enum.each(trend_changes, fn change ->
      if change.significance > @significant_change_threshold do
        trigger_notification(%{
          type: :market_trend,
          topic: change.topic,
          change: change.direction,
          significance: change.significance,
          context: change.context
        })
      end
    end)
    
    state
  end
  
  defp spike_detected?(current, baseline) when is_number(current) and is_number(baseline) do
    baseline > 0 and (current / baseline) >= @spike_threshold
  end
  defp spike_detected?(_, _), do: false
  
  defp calculate_change_percent(current, baseline) when baseline > 0 do
    ((current - baseline) / baseline * 100) |> Float.round(1)
  end
  defp calculate_change_percent(_, _), do: 0
  
  defp trigger_notification(trigger_data) do
    Logger.info("Trigger detected: #{inspect(trigger_data)}")
    
    # Generate AI analysis of the trigger
    analysis = generate_trigger_analysis(trigger_data)
    
    # Send notification
    Notifications.send_trigger_alert(trigger_data, analysis)
    
    # Store for dashboard display
    store_trigger_event(trigger_data, analysis)
  end
  
  defp generate_trigger_analysis(trigger_data) do
    prompt = build_trigger_analysis_prompt(trigger_data)
    
    case CodexClient.ask(prompt) do
      {:ok, analysis} -> analysis
      {:error, _} -> "Unable to generate analysis at this time."
    end
  end
  
  defp build_trigger_analysis_prompt(%{type: :analytics_spike} = data) do
    """
    ANALYTICS SPIKE DETECTED
    
    Metric: #{data.metric}
    Current Value: #{data.current}
    Baseline: #{data.baseline} 
    Change: +#{data.change_percent}%
    
    Analyze this spike and provide:
    1. Potential causes
    2. Whether this is likely positive or concerning
    3. Recommended actions
    4. What to monitor next
    
    Keep response concise (2-3 sentences).
    """
  end
  
  defp build_trigger_analysis_prompt(%{type: :competitor_spike} = data) do
    """
    COMPETITOR ACTIVITY SPIKE DETECTED
    
    Company: #{data.company}
    Activity: #{data.metric} (#{data.current} vs baseline #{data.baseline})
    Recent Content: #{Enum.join(data.recent_titles, "; ")}
    
    Analyze this activity spike and provide:
    1. Strategic implications for us
    2. Potential competitive threats/opportunities
    3. Recommended monitoring or response
    
    Keep response concise (2-3 sentences).
    """
  end
  
  defp build_trigger_analysis_prompt(%{type: :market_trend} = data) do
    """
    MARKET TREND CHANGE DETECTED
    
    Topic: #{data.topic}
    Direction: #{data.change}
    Significance: #{data.significance}
    Context: #{data.context}
    
    Analyze this trend change and provide:
    1. Impact on financial services industry
    2. Opportunities or risks for AllianceBernstein
    3. Recommended strategic response
    
    Keep response concise (2-3 sentences).
    """
  end
  
  # Helper functions
  defp get_current_analytics_metrics do
    summary = Analytics.get_analytics_summary(1) # Last 24 hours
    %{
      page_views: summary.total_page_views || 0,
      conversions: Map.get(summary.conversion_metrics, :conversions, 0)
    }
  end
  
  defp get_recent_titles(company, type, limit) do
    # This would fetch recent titles from the insights system
    case Insights.get_recent_content(company, type, limit) do
      {:ok, content} -> Enum.map(content, & &1.title)
      _ -> []
    end
  end
  
  defp merge_activity_baselines(baseline, current) do
    Enum.reduce(current, baseline, fn {company, activity}, acc ->
      existing = Map.get(acc, company, activity)
      updated = %{
        press_releases: (existing.press_releases * 0.8 + activity.press_releases * 0.2),
        social_posts: (existing.social_posts * 0.8 + activity.social_posts * 0.2)
      }
      Map.put(acc, company, updated)
    end)
  end
  
  defp detect_trending_topics do
    # Analyze recent content for trending keywords/topics
    # This would use NLP to detect emerging themes
    []
  end
  
  defp store_trigger_event(_trigger_data, _analysis) do
    # Store in database for dashboard display
    # Could create a triggers table to track all events
    :ok
  end
end