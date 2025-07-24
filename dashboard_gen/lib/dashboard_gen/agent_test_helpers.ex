defmodule DashboardGen.AgentTestHelpers do
  @moduledoc """
  Test helpers for manually testing agent functionality.
  
  Use these functions in IEx to test the new agent features.
  """
  
  alias DashboardGen.{
    AgentRouter, AgentTagging, TimeComparison, 
    PlanningAgents, AgentMonitor,
    AlertStore, Notifications
  }
  
  @doc """
  Test the agent router with sample queries
  """
  def test_agent_router do
    queries = [
      "How has our homepage been performing lately?",
      "What are BlackRock's recent competitive moves?", 
      "Show me quarterly trends for our analytics",
      "Which competitor is most active this week?"
    ]
    
    IO.puts("🤖 Testing Agent Router...")
    
    Enum.each(queries, fn query ->
      IO.puts("\n📝 Query: #{query}")
      
      case AgentRouter.classify_query_intent(query) do
        intent when is_map(intent) ->
          IO.puts("✅ Intent Classification:")
          IO.puts("   Primary Intent: #{intent.primary_intent}")
          IO.puts("   Data Sources: #{inspect(intent.data_sources)}")
          IO.puts("   Analysis Type: #{intent.analysis_type}")
          IO.puts("   Time Scope: #{intent.time_scope}")
          
        error ->
          IO.puts("❌ Error: #{inspect(error)}")
      end
    end)
  end
  
  @doc """
  Test the content tagging system
  """
  def test_content_tagging do
    sample_content = %{
      title: "BlackRock Launches New AI-Powered ESG Investment Platform",
      text: "BlackRock today announced the launch of their revolutionary AI-powered ESG investment platform, designed to help institutional investors make more sustainable investment decisions. The platform uses machine learning to analyze environmental, social, and governance factors across thousands of securities.",
      source: "press_release",
      date: "2024-01-15"
    }
    
    IO.puts("🏷️ Testing Content Tagging...")
    IO.puts("📄 Sample Content: #{sample_content.title}")
    
    case AgentTagging.tag_content(sample_content) do
      %{tags: tags} ->
        IO.puts("✅ Tagging Results:")
        IO.puts("   Topics: #{inspect(tags.topics)}")
        IO.puts("   Sentiment: #{tags.sentiment}")
        IO.puts("   Strategic Relevance: #{tags.strategic_relevance}")
        IO.puts("   Key Insights: #{inspect(tags.key_insights)}")
        
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
  
  @doc """
  Test time comparison analysis
  """
  def test_time_comparison do
    IO.puts("📊 Testing Time Comparison...")
    
    # Test quarterly comparison
    current_year = Date.utc_today().year
    
    case TimeComparison.quarter_over_quarter(current_year, 1) do
      %{comparison: comparison} ->
        IO.puts("✅ Q1 vs Q4 Comparison:")
        IO.puts("   Analytics Growth: #{inspect(comparison.growth_rates)}")
        IO.puts("   Significant Changes: #{inspect(comparison.significant_changes)}")
        
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
  
  @doc """
  Test alert store functionality
  """
  def test_alert_store do
    IO.puts("🚨 Testing Alert Store...")
    
    # Create sample alert
    sample_alert = %{
      id: "test-alert-#{:rand.uniform(1000)}",
      type: :analytics_spike,
      severity: :high,
      title: "Test Analytics Spike",
      message: "This is a test alert for demonstration",
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      metadata: %{test: true}
    }
    
    # Store the alert
    AlertStore.store_alert(sample_alert)
    IO.puts("✅ Stored test alert: #{sample_alert.id}")
    
    # Retrieve recent alerts
    case AlertStore.get_recent_alerts(5) do
      alerts when is_list(alerts) ->
        IO.puts("📋 Recent Alerts (#{length(alerts)}):")
        Enum.each(alerts, fn alert ->
          IO.puts("   - #{alert.title} (#{alert.severity}) - #{alert.timestamp}")
        end)
        
      error ->
        IO.puts("❌ Error retrieving alerts: #{inspect(error)}")
    end
    
    # Get alert statistics
    case AlertStore.get_alert_stats() do
      stats when is_map(stats) ->
        IO.puts("📈 Alert Statistics:")
        IO.puts("   Total Alerts: #{stats.total_alerts}")
        IO.puts("   Last 24h: #{stats.alerts_last_24h}")
        IO.puts("   Unacknowledged: #{stats.unacknowledged}")
        
      error ->
        IO.puts("❌ Error getting stats: #{inspect(error)}")
    end
  end
  
  @doc """
  Test notifications system
  """
  def test_notifications do
    IO.puts("📢 Testing Notifications...")
    
    # Test analytics spike notification
    trigger_data = %{
      type: :analytics_spike,
      metric: "page_views",
      current: 5000,
      baseline: 2500,
      change_percent: 100.0
    }
    
    analysis = "This spike appears to be driven by increased organic traffic, likely from a viral social media post or news coverage."
    
    case Notifications.send_trigger_alert(trigger_data, analysis) do
      :ok ->
        IO.puts("✅ Analytics spike notification sent successfully")
        
      error ->
        IO.puts("❌ Error sending notification: #{inspect(error)}")
    end
    
    # Test competitor spike notification
    competitor_data = %{
      type: :competitor_spike,
      company: "BlackRock",
      metric: "press_releases",
      current: 5,
      baseline: 2,
      recent_titles: ["New AI Platform Launch", "ESG Investment Strategy", "Q4 Earnings Beat"]
    }
    
    competitor_analysis = "BlackRock is showing increased communication activity, particularly around AI and ESG themes. This suggests a strategic push in these areas."
    
    case Notifications.send_trigger_alert(competitor_data, competitor_analysis) do
      :ok ->
        IO.puts("✅ Competitor spike notification sent successfully")
        
      error ->
        IO.puts("❌ Error sending competitor notification: #{inspect(error)}")
    end
  end
  
  @doc """
  Test agent monitoring
  """
  def test_agent_monitoring do
    IO.puts("🔧 Testing Agent Monitoring...")
    
    case AgentMonitor.get_health_status() do
      health when is_map(health) ->
        IO.puts("✅ System Health Status:")
        IO.puts("   Overall Status: #{health.overall_status}")
        IO.puts("   Uptime: #{health.uptime_seconds} seconds")
        IO.puts("   Success Rate: #{Float.round(health.success_rate * 100, 1)}%")
        IO.puts("   Avg Response Time: #{Float.round(health.average_response_time, 1)}ms")
        
        if health.system_metrics != %{} do
          IO.puts("   System Metrics: #{inspect(health.system_metrics)}")
        end
        
      error ->
        IO.puts("❌ Error getting health status: #{inspect(error)}")
    end
    
    # Test recording a request
    AgentMonitor.record_request(:analytics_query, 1500, :success)
    IO.puts("✅ Recorded test request")
    
    # Test recording an error
    AgentMonitor.record_error(:test_error, "This is a test error", %{component: "test"})
    IO.puts("✅ Recorded test error")
  end
  
  @doc """
  Test planning agents (manual trigger)
  """
  def test_planning_agents do
    IO.puts("📅 Testing Planning Agents...")
    
    IO.puts("🎯 Triggering marketing brief generation...")
    PlanningAgents.generate_marketing_brief()
    IO.puts("✅ Marketing brief generation started (check logs)")
    
    IO.puts("🏢 Triggering competitive summary generation...")
    PlanningAgents.generate_competitive_summary()
    IO.puts("✅ Competitive summary generation started (check logs)")
  end
  
  @doc """
  Run all tests
  """
  def run_all_tests do
    IO.puts("🚀 Running All Agent Tests...\n")
    
    test_agent_router()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_content_tagging()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_time_comparison()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_alert_store()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_notifications()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_agent_monitoring()
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
    
    test_planning_agents()
    
    IO.puts("\n🎉 All tests completed!")
  end
  
  @doc """
  Start all agent processes for testing
  """
  def start_agents do
    IO.puts("🤖 Starting Agent Processes...")
    
    # Start agent processes
    processes = [
      {DashboardGen.AlertStore, []},
      {DashboardGen.AgentMonitor, []},
      {DashboardGen.AgentTriggers, []},
      {DashboardGen.PlanningAgents, []}
    ]
    
    Enum.each(processes, fn {module, args} ->
      case GenServer.start_link(module, args, name: module) do
        {:ok, _pid} ->
          IO.puts("✅ Started #{module}")
        {:error, {:already_started, _pid}} ->
          IO.puts("ℹ️  #{module} already running")
        {:error, reason} ->
          IO.puts("❌ Failed to start #{module}: #{inspect(reason)}")
      end
    end)
    
    IO.puts("🎉 Agent processes startup complete!")
  end
  
  @doc """
  Create sample data for testing
  """
  def create_sample_data do
    IO.puts("📊 Creating Sample Data...")
    
    # This would create sample analytics data, competitor insights, etc.
    # For now, just show what would be created
    
    IO.puts("✅ Sample data creation would include:")
    IO.puts("   - Analytics page views and events")
    IO.puts("   - Competitor press releases and social posts")
    IO.puts("   - Sample insights and trends")
    IO.puts("   - Mock performance metrics")
    
    IO.puts("💡 In a real environment, this would populate your database with test data")
  end
end