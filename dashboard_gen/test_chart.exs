#!/usr/bin/env elixir

# Test script to validate chart generation
IO.puts("Testing chart generation...")

case DashboardGen.Analytics.analyze_question("show me a chart of page views") do
  {:ok, analysis, chart_data} ->
    IO.puts("✅ Chart generation successful!")
    IO.puts("Analysis: #{String.slice(analysis, 0, 100)}...")
    IO.puts("Chart type: #{chart_data.type}")
    IO.puts("Chart labels: #{inspect(Enum.take(chart_data.data.labels, 3))}")
  {:ok, analysis} ->
    IO.puts("⚠️ Text-only response: #{String.slice(analysis, 0, 100)}...")  
  {:error, reason} ->
    IO.puts("❌ Chart generation failed: #{reason}")
end

IO.puts("\nTesting non-chart request...")
case DashboardGen.Analytics.analyze_question("what are our main competitors?") do
  {:ok, analysis} ->
    IO.puts("✅ Regular analysis successful!")
    IO.puts("Response: #{String.slice(analysis, 0, 100)}...")
  {:error, reason} ->
    IO.puts("❌ Analysis failed: #{reason}")
end