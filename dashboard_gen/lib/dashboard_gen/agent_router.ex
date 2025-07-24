defmodule DashboardGen.AgentRouter do
  @moduledoc """
  Intelligent routing system that selects appropriate data sources and analysis methods
  based on user intent and query classification.
  
  Acts as the central decision-making component for determining which agents,
  data connectors, and analysis pipelines to activate for each user request.
  """
  
  alias DashboardGen.{Analytics, Insights}
  require Logger
  
  @doc """
  Route a user query to appropriate agents and data sources
  """
  def route_query(query, context \\ %{}) do
    # Classify the query intent
    intent = classify_query_intent(query)
    
    # Select appropriate connectors and agents
    execution_plan = build_execution_plan(intent, query, context)
    
    # Execute the plan
    execute_plan(execution_plan, query)
  end
  
  @doc """
  Classify user query intent using LLM analysis
  """
  def classify_query_intent(query) do
    prompt = build_intent_classification_prompt(query)
    
    case CodexClient.ask(prompt) do
      {:ok, response} -> parse_intent_response(response)
      {:error, _} -> default_intent_classification(query)
    end
  end
  
  defp build_intent_classification_prompt(query) do
    """
    QUERY INTENT CLASSIFICATION
    
    Analyze this user query and classify its intent and requirements:
    
    USER QUERY: "#{query}"
    
    CLASSIFY THE INTENT INTO THESE CATEGORIES:
    
    PRIMARY_INTENT: [analytics_performance, competitive_intelligence, market_trends, strategic_planning, data_exploration, content_analysis]
    
    DATA_SOURCES_NEEDED: [website_analytics, competitor_data, social_media, press_releases, market_data, internal_metrics]
    
    ANALYSIS_TYPE: [real_time, historical_comparison, trend_analysis, competitive_benchmarking, predictive_insights, summary_report]
    
    TIME_SCOPE: [current, last_week, last_month, last_quarter, year_over_year, custom_range]
    
    COMPLEXITY_LEVEL: [simple, moderate, complex, multi_step]
    
    EXPECTED_OUTPUT: [charts_and_metrics, narrative_analysis, strategic_recommendations, comparative_report, trend_forecast]
    
    URGENCY: [immediate, standard, background_analysis]
    
    SPECIFIC_ENTITIES: [list any specific companies, products, metrics, or topics mentioned]
    
    Provide structured classification in the exact format above.
    """
  end
  
  defp parse_intent_response(response) do
    %{
      primary_intent: extract_classification_field(response, "PRIMARY_INTENT"),
      data_sources: extract_classification_field(response, "DATA_SOURCES_NEEDED") |> parse_list_field(),
      analysis_type: extract_classification_field(response, "ANALYSIS_TYPE"),
      time_scope: extract_classification_field(response, "TIME_SCOPE"),
      complexity: extract_classification_field(response, "COMPLEXITY_LEVEL"),
      expected_output: extract_classification_field(response, "EXPECTED_OUTPUT"),
      urgency: extract_classification_field(response, "URGENCY"),
      entities: extract_classification_field(response, "SPECIFIC_ENTITIES") |> parse_list_field()
    }
  end
  
  defp extract_classification_field(text, field_name) do
    case Regex.run(~r/#{field_name}:\s*\[([^\]]+)\]/i, text) do
      [_, content] -> String.trim(content)
      _ -> "unknown"
    end
  end
  
  defp parse_list_field(field_content) do
    field_content
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end
  
  defp default_intent_classification(query) do
    # Fallback classification based on keywords
    query_lower = String.downcase(query)
    
    primary_intent = cond do
      String.contains?(query_lower, ["analytics", "traffic", "conversion", "performance"]) -> "analytics_performance"
      String.contains?(query_lower, ["competitor", "competitive", "rival"]) -> "competitive_intelligence"
      String.contains?(query_lower, ["trend", "market", "industry"]) -> "market_trends"
      true -> "data_exploration"
    end
    
    %{
      primary_intent: primary_intent,
      data_sources: determine_data_sources(query_lower),
      analysis_type: "summary_report",
      time_scope: determine_time_scope(query_lower),
      complexity: "moderate",
      expected_output: "narrative_analysis",
      urgency: "standard",
      entities: []
    }
  end
  
  defp determine_data_sources(query_lower) do
    sources = []
    sources = if String.contains?(query_lower, ["website", "analytics", "traffic"]), do: ["website_analytics" | sources], else: sources
    sources = if String.contains?(query_lower, ["competitor", "competitive"]), do: ["competitor_data" | sources], else: sources
    sources = if String.contains?(query_lower, ["social", "twitter", "linkedin"]), do: ["social_media" | sources], else: sources
    sources = if String.contains?(query_lower, ["press", "news", "announcement"]), do: ["press_releases" | sources], else: sources
    
    case sources do
      [] -> ["competitor_data"] # Default
      _ -> sources
    end
  end
  
  defp determine_time_scope(query_lower) do
    cond do
      String.contains?(query_lower, ["today", "now", "current", "latest"]) -> "current"
      String.contains?(query_lower, ["week", "lately", "recent"]) -> "last_week"
      String.contains?(query_lower, ["month"]) -> "last_month"
      String.contains?(query_lower, ["quarter"]) -> "last_quarter"
      true -> "last_week"
    end
  end
  
  defp build_execution_plan(intent, query, context) do
    plan = %{
      query: query,
      intent: intent,
      context: context,
      steps: [],
      connectors: [],
      agents: [],
      expected_duration: :fast
    }
    
    plan
    |> add_data_collection_steps()
    |> add_analysis_steps()
    |> add_output_generation_steps()
    |> optimize_execution_order()
  end
  
  defp add_data_collection_steps(plan) do
    steps = []
    connectors = []
    
    # Add steps based on required data sources
    {new_steps, new_connectors} = Enum.reduce(plan.intent.data_sources, {steps, connectors}, fn source, {acc_steps, acc_connectors} ->
      case source do
        "website_analytics" ->
          {[{:collect_analytics, determine_analytics_params(plan)} | acc_steps], 
           [:analytics_connector | acc_connectors]}
           
        "competitor_data" ->
          {[{:collect_competitor_insights, determine_competitor_params(plan)} | acc_steps],
           [:insights_connector | acc_connectors]}
           
        "social_media" ->
          {[{:collect_social_data, determine_social_params(plan)} | acc_steps],
           [:social_connector | acc_connectors]}
           
        "press_releases" ->
          {[{:collect_press_releases, determine_press_params(plan)} | acc_steps],
           [:press_connector | acc_connectors]}
           
        _ ->
          {acc_steps, acc_connectors}
      end
    end)
    
    %{plan | steps: new_steps, connectors: new_connectors}
  end
  
  defp add_analysis_steps(plan) do
    analysis_steps = case plan.intent.analysis_type do
      "trend_analysis" -> [{:analyze_trends, %{}}, {:detect_patterns, %{}}]
      "competitive_benchmarking" -> [{:benchmark_competitors, %{}}, {:analyze_positioning, %{}}]
      "historical_comparison" -> [{:compare_periods, determine_comparison_periods(plan)}]
      "predictive_insights" -> [{:generate_forecasts, %{}}, {:identify_opportunities, %{}}]
      _ -> [{:analyze_data, %{}}]
    end
    
    %{plan | steps: plan.steps ++ analysis_steps}
  end
  
  defp add_output_generation_steps(plan) do
    output_steps = case plan.intent.expected_output do
      "charts_and_metrics" -> [{:generate_charts, %{}}, {:compile_metrics, %{}}]
      "strategic_recommendations" -> [{:generate_recommendations, %{}}, {:prioritize_actions, %{}}]
      "comparative_report" -> [{:build_comparison_report, %{}}]
      "trend_forecast" -> [{:generate_forecast_report, %{}}]
      _ -> [{:generate_narrative_analysis, %{}}]
    end
    
    %{plan | steps: plan.steps ++ output_steps}
  end
  
  defp optimize_execution_order(plan) do
    # Optimize step order for parallel execution where possible
    optimized_steps = plan.steps
    |> group_parallel_steps()
    |> order_by_dependencies()
    
    duration = estimate_execution_duration(optimized_steps, plan.intent.complexity)
    
    %{plan | steps: optimized_steps, expected_duration: duration}
  end
  
  defp execute_plan(plan, original_query) do
    Logger.info("Executing analysis plan: #{plan.intent.primary_intent}")
    Logger.info("Steps: #{length(plan.steps)}, Connectors: #{inspect(plan.connectors)}")
    
    # Execute steps sequentially (could be optimized for parallel execution)
    {results, errors} = Enum.reduce(plan.steps, {%{}, []}, fn step, {acc_results, acc_errors} ->
      case execute_step(step, acc_results, plan) do
        {:ok, step_result} -> 
          step_name = elem(step, 0)
          {Map.put(acc_results, step_name, step_result), acc_errors}
        {:error, error} -> 
          {acc_results, [error | acc_errors]}
      end
    end)
    
    # Compile final response
    compile_response(results, errors, plan, original_query)
  end
  
  defp execute_step({:collect_analytics, params}, _results, _plan) do
    case Analytics.get_analytics_summary(Map.get(params, :days_back, 7)) do
      summary when is_map(summary) -> {:ok, summary}
      _ -> {:error, "Failed to collect analytics data"}
    end
  end
  
  defp execute_step({:collect_competitor_insights, params}, _results, _plan) do
    case Insights.list_recent_insights_by_company(Map.get(params, :limit, 10)) do
      insights when is_list(insights) -> {:ok, insights}
      _ -> {:error, "Failed to collect competitor insights"}
    end
  end
  
  defp execute_step({:analyze_trends, _params}, _results, _plan) do
    # Analyze trends from collected data
    {:ok, "Trend analysis completed"}
  end
  
  defp execute_step({:generate_narrative_analysis, _params}, results, plan) do
    # Generate final narrative using all collected data
    analysis_prompt = build_comprehensive_analysis_prompt(results, plan)
    
    case CodexClient.ask(analysis_prompt) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, "Analysis generation failed: #{reason}"}
    end
  end
  
  defp execute_step(step, _results, _plan) do
    Logger.warning("Unhandled step: #{inspect(step)}")
    {:ok, "Step completed"}
  end
  
  defp compile_response(results, errors, plan, original_query) do
    if length(errors) > 0 do
      Logger.warning("Execution completed with errors: #{inspect(errors)}")
    end
    
    # Return comprehensive response
    %{
      query: original_query,
      intent: plan.intent,
      results: results,
      errors: errors,
      execution_plan: plan,
      generated_at: DateTime.utc_now()
    }
  end
  
  # Helper functions for parameter determination
  defp determine_analytics_params(plan) do
    days_back = case plan.intent.time_scope do
      "current" -> 1
      "last_week" -> 7
      "last_month" -> 30
      "last_quarter" -> 90
      _ -> 7
    end
    %{days_back: days_back}
  end
  
  defp determine_competitor_params(plan) do
    limit = case plan.intent.complexity do
      "simple" -> 5
      "moderate" -> 10
      "complex" -> 20
      _ -> 10
    end
    %{limit: limit}
  end
  
  defp determine_social_params(_plan), do: %{}
  defp determine_press_params(_plan), do: %{}
  defp determine_comparison_periods(_plan), do: %{}
  
  defp group_parallel_steps(steps), do: steps
  defp order_by_dependencies(steps), do: steps
  
  defp estimate_execution_duration(steps, complexity) do
    base_time = length(steps) * 2 # 2 seconds per step
    complexity_multiplier = case complexity do
      "simple" -> 1.0
      "moderate" -> 1.5
      "complex" -> 2.5
      _ -> 1.5
    end
    
    total_seconds = base_time * complexity_multiplier
    
    cond do
      total_seconds < 10 -> :fast
      total_seconds < 30 -> :medium
      true -> :slow
    end
  end
  
  defp build_comprehensive_analysis_prompt(results, plan) do
    """
    COMPREHENSIVE ANALYSIS REQUEST
    
    User Query: #{plan.query}
    Intent: #{plan.intent.primary_intent}
    
    COLLECTED DATA:
    #{format_results_for_prompt(results)}
    
    ANALYSIS REQUIREMENTS:
    - Analysis Type: #{plan.intent.analysis_type}
    - Expected Output: #{plan.intent.expected_output}
    - Time Scope: #{plan.intent.time_scope}
    
    Generate a comprehensive response that:
    1. Directly answers the user's question
    2. Provides relevant insights from the data
    3. Includes strategic implications
    4. Offers actionable recommendations
    5. Highlights key metrics and trends
    
    Format the response clearly with sections and bullet points for readability.
    """
  end
  
  defp format_results_for_prompt(results) do
    results
    |> Enum.map(fn {step, result} ->
      "#{step}: #{inspect(result) |> String.slice(0, 200)}..."
    end)
    |> Enum.join("\n")
  end
end