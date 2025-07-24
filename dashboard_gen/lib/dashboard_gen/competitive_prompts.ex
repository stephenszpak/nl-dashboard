defmodule DashboardGen.CompetitivePrompts do
  @moduledoc """
  Manages competitive intelligence prompt categories, templates, and smart suggestions.
  
  Provides context-aware prompts based on current competitor data and recent activities.
  """
  
  alias DashboardGen.Insights
  
  @doc """
  Get all prompt categories with their templates
  """
  def get_categories do
    %{
      "quick_analysis" => %{
        name: "🔍 Quick Analysis",
        description: "Fast insights on competitor activities",
        color: "blue",
        prompts: quick_analysis_prompts()
      },
      "strategic_deep_dive" => %{
        name: "🎯 Strategic Deep Dive", 
        description: "Comprehensive competitive analysis",
        color: "purple",
        prompts: strategic_prompts()
      },
      "trend_detection" => %{
        name: "📈 Trend Detection",
        description: "Identify emerging patterns and opportunities",
        color: "green",
        prompts: trend_prompts()
      },
      "threat_assessment" => %{
        name: "⚠️ Threat Assessment",
        description: "Risk analysis and competitive threats",
        color: "red",
        prompts: threat_prompts()
      },
      "opportunity_mining" => %{
        name: "💎 Opportunity Mining",
        description: "Find market gaps and growth opportunities",
        color: "yellow",
        prompts: opportunity_prompts()
      },
      "response_planning" => %{
        name: "⚡ Response Planning",
        description: "Actionable strategies and counter-moves",
        color: "indigo",
        prompts: response_prompts()
      },
      "website_analytics" => %{
        name: "📊 Website Analytics",
        description: "AllianceBernstein.com performance insights",
        color: "emerald",
        prompts: analytics_prompts()
      }
    }
  end
  
  @doc """
  Generate smart suggestions based on recent competitor activity
  """
  def get_smart_suggestions do
    recent_insights = Insights.list_recent_insights_by_company(5)
    
    suggestions = []
    
    # Analyze recent activity patterns
    suggestions = suggestions ++ activity_based_suggestions(recent_insights)
    
    # Check for trending topics
    suggestions = suggestions ++ trending_topic_suggestions(recent_insights)
    
    # Identify unusual competitor behavior
    suggestions = suggestions ++ anomaly_suggestions(recent_insights)
    
    # Add time-sensitive suggestions
    suggestions = suggestions ++ time_sensitive_suggestions()
    
    suggestions
    |> Enum.take(6) # Limit to top 6 suggestions
    |> Enum.with_index(fn suggestion, index -> Map.put(suggestion, :id, index) end)
  end
  
  @doc """
  Get context-aware prompt with real competitor data injected
  """
  def contextualize_prompt(template, context \\ %{}) do
    recent_insights = Insights.list_recent_insights_by_company(3)
    companies = Map.keys(recent_insights)
    
    # Get recent activities for context
    recent_activities = 
      recent_insights
      |> Enum.flat_map(fn {company, data} ->
        (data.press_releases ++ data.social_media)
        |> Enum.take(2)
        |> Enum.map(&"#{company}: #{&1.title}")
      end)
      |> Enum.take(5)
    
    context = Map.merge(context, %{
      companies: companies,
      recent_activities: recent_activities,
      primary_competitors: Enum.take(companies, 3),
      activity_count: length(recent_activities)
    })
    
    inject_context(template, context)
  end
  
  ## Private Functions - Prompt Templates
  
  defp quick_analysis_prompts do
    [
      "Which competitor has been most active on social media this week?",
      "Show me the top 3 trending topics across all competitors",
      "What's the sentiment breakdown of recent competitor press releases?",
      "Which competitor announced the most new products recently?",
      "Compare social media engagement rates across competitors",
      "Identify competitors with declining PR activity",
      "What themes are competitors focusing on in their messaging?"
    ]
  end
  
  defp strategic_prompts do
    [
      "Conduct a SWOT analysis comparing our position to {primary_competitor}",
      "Analyze {competitor}'s strategic direction based on their recent announcements",
      "Identify market segments where competitors are gaining ground",
      "Compare competitive advantages across all major players",
      "Assess which competitor has the strongest digital transformation strategy",
      "Evaluate competitor partnership strategies and their market impact",
      "Analyze competitive positioning in ESG and sustainable investing"
    ]
  end
  
  defp trend_prompts do
    [
      "What emerging trends are competitors investing in that we should monitor?",
      "Identify patterns in competitor product launch timing",
      "Predict which competitor is likely to make the next major acquisition", 
      "Analyze correlation between competitor PR campaigns and market events",
      "Show how competitor messaging has evolved over the past 6 months",
      "Identify cyclical patterns in competitor announcement strategies",
      "Track competitor adoption of new technologies and innovations"
    ]
  end
  
  defp threat_prompts do
    [
      "Identify immediate competitive threats requiring urgent response",
      "Assess which competitor poses the greatest long-term risk",
      "Analyze potential market disruption from competitor activities",
      "Evaluate competitor moves that could impact our market share",
      "Identify competitors who are aggressively targeting our key segments",
      "Assess regulatory or compliance advantages competitors may have",
      "Analyze competitor talent acquisition that could signal strategic shifts"
    ]
  end
  
  defp opportunity_prompts do
    [
      "Find market gaps where competitors are underperforming",
      "Identify customer segments competitors are neglecting",
      "Spot opportunities where we can outmaneuver competitor strategies",
      "Find partnership opportunities competitors haven't explored",
      "Identify geographic markets with weak competitive presence",
      "Discover product features competitors are missing",
      "Find messaging angles competitors aren't effectively using"
    ]
  end
  
  defp response_prompts do
    [
      "Generate counter-strategies for {competitor}'s recent product launch",
      "Create talking points to address {competitor}'s competitive advantages",
      "Develop messaging to differentiate from {competitor}'s positioning",
      "Suggest partnerships that would counter {competitor}'s market position",
      "Recommend product features to stay competitive with {competitor}",
      "Create a roadmap to match or exceed {competitor}'s capabilities",
      "Generate PR strategy to respond to {competitor}'s recent announcements"
    ]
  end
  
  defp analytics_prompts do
    [
      "How has our US homepage been performing lately based on user interactions?",
      "Analyze fund search behavior and conversion patterns on our website",
      "What are the top performing pages on alliancebernstein.com this month?",
      "Compare mobile vs desktop user engagement on our fund pages",
      "Identify drop-off points in our website user journey",
      "What content types are driving the most engagement?",
      "Analyze geographic patterns in our website traffic and conversions",
      "How effective are our call-to-action buttons across different pages?",
      "What search terms are users entering on our fund search page?",
      "Compare bounce rates across our different investment product pages",
      "Analyze user behavior flow from homepage to fund details",
      "What time of day do we see peak engagement on our insights content?",
      "How do users navigate through our fund comparison tools?",
      "Identify our highest converting traffic sources and campaigns",
      "Analyze session duration patterns across different visitor segments"
    ]
  end
  
  ## Private Functions - Smart Suggestions
  
  defp activity_based_suggestions(recent_insights) do
    suggestions = []
    
    # High activity competitors
    active_companies = 
      recent_insights
      |> Enum.map(fn {company, data} -> 
        {company, length(data.press_releases) + length(data.social_media)}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(2)
    
    suggestions = suggestions ++ Enum.map(active_companies, fn {company, count} ->
      %{
        type: "high_activity",
        priority: "high",
        title: "🚨 High Activity Alert",
        prompt: "#{company} has been very active recently (#{count} posts). What strategy are they pursuing?",
        reason: "#{company} shows increased activity",
        category: "threat_assessment"
      }
    end)
    
    # Low activity (potential strategic shift)
    low_activity = 
      recent_insights
      |> Enum.filter(fn {_company, data} -> 
        length(data.press_releases) + length(data.social_media) < 2
      end)
      |> Enum.take(1)
    
    suggestions = suggestions ++ Enum.map(low_activity, fn {company, _data} ->
      %{
        type: "low_activity",
        priority: "medium", 
        title: "📉 Quiet Competitor",
        prompt: "#{company} has been unusually quiet. Are they planning something big?",
        reason: "Unusual silence from #{company}",
        category: "trend_detection"
      }
    end)
    
    suggestions
  end
  
  defp trending_topic_suggestions(recent_insights) do
    # Extract common themes from recent content
    all_content = 
      recent_insights
      |> Enum.flat_map(fn {_company, data} ->
        (data.press_releases ++ data.social_media)
        |> Enum.map(&(&1.title <> " " <> (&1.content || "")))
      end)
      |> Enum.join(" ")
      |> String.downcase()
    
    trending_topics = []
    
    # Check for hot topics
    trending_topics = trending_topics ++ cond do
      String.contains?(all_content, "ai") or String.contains?(all_content, "artificial intelligence") ->
        [%{
          type: "trending_topic",
          priority: "high",
          title: "🤖 AI Trend",
          prompt: "Analyze how competitors are positioning themselves in the AI space",
          reason: "Multiple competitors mentioning AI",
          category: "trend_detection"
        }]
      true -> []
    end
    
    trending_topics = trending_topics ++ cond do
      String.contains?(all_content, "esg") or String.contains?(all_content, "sustainability") ->
        [%{
          type: "trending_topic", 
          priority: "medium",
          title: "🌱 ESG Focus",
          prompt: "Compare ESG strategies across competitors and identify our positioning",
          reason: "ESG mentioned frequently",
          category: "strategic_deep_dive"
        }]
      true -> []
    end
    
    trending_topics = trending_topics ++ cond do
      String.contains?(all_content, "digital") or String.contains?(all_content, "technology") ->
        [%{
          type: "trending_topic",
          priority: "medium", 
          title: "💻 Digital Transformation",
          prompt: "Assess digital transformation progress across competitors",
          reason: "Digital initiatives trending",
          category: "strategic_deep_dive"
        }]
      true -> []
    end
    
    trending_topics
  end
  
  defp anomaly_suggestions(recent_insights) do
    suggestions = []
    
    # Check for YouTube content without engagement metrics (new content)
    new_youtube_content = 
      recent_insights
      |> Enum.flat_map(fn {company, data} ->
        data.social_media
        |> Enum.filter(fn post -> 
          String.contains?(post.url || "", "youtube.com") and is_nil(Map.get(post, :view_count))
        end)
        |> Enum.map(&{company, &1})
      end)
    
    suggestions = if length(new_youtube_content) > 0 do
      {company, _post} = List.first(new_youtube_content)
      suggestions ++ [%{
        type: "new_content",
        priority: "medium",
        title: "📺 New Video Content", 
        prompt: "#{company} posted new YouTube content. Analyze their video marketing strategy",
        reason: "New video content detected",
        category: "quick_analysis"
      }]
    else
      suggestions
    end
    
    suggestions
  end
  
  defp time_sensitive_suggestions do
    current_hour = DateTime.utc_now().hour
    current_day = Date.day_of_week(Date.utc_today())
    
    suggestions = []
    
    # Monday morning strategic planning
    suggestions = if current_day == 1 and current_hour < 12 do
      suggestions ++ [%{
        type: "time_sensitive",
        priority: "medium",
        title: "📅 Weekly Planning",
        prompt: "What should we monitor this week based on last week's competitor activities?",
        reason: "Monday morning strategic planning",
        category: "response_planning"
      }]
    else
      suggestions
    end
    
    # Friday afternoon wrap-up
    suggestions = if current_day == 5 and current_hour > 15 do
      suggestions ++ [%{
        type: "time_sensitive", 
        priority: "low",
        title: "📊 Weekly Wrap-up",
        prompt: "Summarize this week's key competitive intelligence insights",
        reason: "End of week summary",
        category: "quick_analysis"
      }]
    else
      suggestions
    end
    
    suggestions
  end
  
  defp inject_context(template, context) do
    template
    |> String.replace("{companies}", Enum.join(context[:companies] || [], ", "))
    |> String.replace("{primary_competitor}", List.first(context[:primary_competitors] || ["BlackRock"]))
    |> String.replace("{competitor}", List.first(context[:companies] || ["BlackRock"]))
    |> String.replace("{recent_activities}", Integer.to_string(context[:activity_count] || 0))
  end
end