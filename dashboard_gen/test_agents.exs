#!/usr/bin/env elixir

# Agent Testing Script
# Run with: elixir test_agents.exs

# Add the lib directory to the code path
Code.prepend_path("lib")

# Load the application
Application.load(:dashboard_gen)

IO.puts("🚀 Agent Testing Script")
IO.puts("======================")

# Test the agent router classification
IO.puts("\n1. Testing Agent Router Classification...")

test_queries = [
  "How has our homepage been performing lately?",
  "What are BlackRock's recent moves?",
  "Show me quarterly analytics trends"
]

Enum.each(test_queries, fn query ->
  IO.puts("\nQuery: #{query}")
  
  # Simple keyword-based classification test
  query_lower = String.downcase(query)
  
  intent = cond do
    String.contains?(query_lower, ["analytics", "performance", "homepage"]) ->
      "analytics_performance"
    String.contains?(query_lower, ["blackrock", "competitor", "moves"]) ->
      "competitive_intelligence"
    String.contains?(query_lower, ["quarterly", "trends"]) ->
      "trend_analysis"
    true ->
      "general_query"
  end
  
  IO.puts("  → Intent: #{intent}")
end)

IO.puts("\n2. Testing Content Tagging Classification...")

sample_content = %{
  title: "BlackRock Launches AI Investment Platform",
  text: "New AI-powered platform for ESG investing",
  source: "press_release"
}

IO.puts("Sample Content: #{sample_content.title}")

# Simple tag classification
tags = []
text_lower = String.downcase(sample_content.text <> " " <> sample_content.title)

tags = if String.contains?(text_lower, ["ai", "artificial intelligence"]), do: ["AI" | tags], else: tags
tags = if String.contains?(text_lower, ["esg", "sustainable"]), do: ["ESG" | tags], else: tags
tags = if String.contains?(text_lower, ["investment", "investing"]), do: ["Asset Management" | tags], else: tags

IO.puts("  → Detected Topics: #{inspect(tags)}")

sentiment = cond do
  String.contains?(text_lower, ["launches", "new", "innovative"]) -> "Positive"
  String.contains?(text_lower, ["fails", "drops", "declines"]) -> "Negative"
  true -> "Neutral"
end

IO.puts("  → Sentiment: #{sentiment}")

IO.puts("\n3. Testing Alert Generation...")

# Simulate an analytics spike
spike_data = %{
  metric: "page_views",
  current: 5000,
  baseline: 2500,
  change_percent: 100.0
}

IO.puts("Analytics Spike Detected:")
IO.puts("  Metric: #{spike_data.metric}")
IO.puts("  Current: #{spike_data.current}")
IO.puts("  Baseline: #{spike_data.baseline}")
IO.puts("  Change: +#{spike_data.change_percent}%")

# Determine severity
severity = cond do
  spike_data.change_percent > 200 -> "Critical"
  spike_data.change_percent > 100 -> "High"
  spike_data.change_percent > 50 -> "Medium"
  true -> "Low"
end

IO.puts("  → Severity: #{severity}")

IO.puts("\n4. Testing Time Comparison...")

# Simulate quarterly comparison
current_q = %{page_views: 50000, conversions: 1200}
previous_q = %{page_views: 45000, conversions: 1100}

page_view_change = ((current_q.page_views - previous_q.page_views) / previous_q.page_views * 100) |> Float.round(1)
conversion_change = ((current_q.conversions - previous_q.conversions) / previous_q.conversions * 100) |> Float.round(1)

IO.puts("Q1 vs Q4 Comparison:")
IO.puts("  Page Views: #{current_q.page_views} vs #{previous_q.page_views} (#{if page_view_change >= 0, do: "+", else: ""}#{page_view_change}%)")
IO.puts("  Conversions: #{current_q.conversions} vs #{previous_q.conversions} (#{if conversion_change >= 0, do: "+", else: ""}#{conversion_change}%)")

IO.puts("\n5. Testing Agent Health Monitoring...")

# Simulate system metrics
uptime_hours = 72.5
success_rate = 0.95
avg_response_time = 850

IO.puts("System Health:")
IO.puts("  Uptime: #{uptime_hours} hours")
IO.puts("  Success Rate: #{Float.round(success_rate * 100, 1)}%")
IO.puts("  Avg Response Time: #{avg_response_time}ms")

health_status = cond do
  success_rate < 0.8 -> "Critical"
  success_rate < 0.9 -> "Warning"
  true -> "Healthy"
end

IO.puts("  → Overall Status: #{health_status}")

IO.puts("\n✅ Agent Testing Complete!")
IO.puts("\nTo test in the actual application:")
IO.puts("1. Start the server: mix phx.server")
IO.puts("2. Open IEx: iex -S mix")
IO.puts("3. Run: DashboardGen.AgentTestHelpers.run_all_tests()")
IO.puts("4. Start agents: DashboardGen.AgentTestHelpers.start_agents()")
IO.puts("5. Test queries in the dashboard web interface")