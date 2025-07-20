defmodule DashboardGen.AutonomousAgent.DecisionEngine do
  @moduledoc """
  Decision-making engine for the autonomous agent.
  
  Evaluates analysis results and historical memory to make intelligent
  decisions about next actions, priorities, and alerts.
  """
  
  alias DashboardGen.AutonomousAgent.Memory
  
  defstruct [:type, :target, :priority, :message, :severity, :confidence]
  
  @doc """
  Evaluate analysis and memory to generate decision list
  """
  def evaluate(analysis, memory) do
    decisions = []
    
    # Analyze trends for opportunities
    decisions = decisions ++ trend_decisions(analysis)
    
    # Check for urgent threats
    decisions = decisions ++ threat_decisions(analysis)
    
    # Prioritize companies based on activity
    decisions = decisions ++ company_priority_decisions(analysis)
    
    # Memory-based decisions (learning from past patterns)
    decisions = decisions ++ memory_based_decisions(analysis, memory)
    
    # Sort by priority and confidence
    decisions
    |> Enum.sort_by(&{&1.priority, &1.confidence}, &>=/2)
    |> Enum.take(5) # Limit to top 5 decisions
  end
  
  defp trend_decisions(analysis) do
    trends = Map.get(analysis, "trends", [])
    
    Enum.flat_map(trends, fn trend ->
      cond do
        trend_indicates_market_shift?(trend) ->
          [%__MODULE__{
            type: :generate_alert,
            message: "Market shift detected: #{trend}",
            severity: :high,
            priority: 0.9,
            confidence: 0.8
          }]
          
        trend_indicates_new_product?(trend) ->
          [%__MODULE__{
            type: :deep_analyze,
            target: extract_company_from_trend(trend),
            message: "New product trend: #{trend}",
            priority: 0.7,
            confidence: 0.75
          }]
          
        true -> []
      end
    end)
  end
  
  defp threat_decisions(analysis) do
    threats = Map.get(analysis, "threats", [])
    
    Enum.map(threats, fn threat ->
      %__MODULE__{
        type: :generate_alert,
        message: "Competitive threat: #{threat}",
        severity: :medium,
        priority: 0.8,
        confidence: 0.7
      }
    end)
  end
  
  defp company_priority_decisions(analysis) do
    priority_companies = Map.get(analysis, "priority_companies", [])
    
    Enum.map(priority_companies, fn company ->
      %__MODULE__{
        type: :scrape_priority_company,
        target: company,
        message: "Increase monitoring for #{company}",
        priority: 0.6,
        confidence: 0.8
      }
    end)
  end
  
  defp memory_based_decisions(analysis, memory) do
    # Check if current analysis shows patterns we've seen before
    historical_patterns = Memory.get_patterns(memory)
    
    Enum.flat_map(historical_patterns, fn pattern ->
      if pattern_matches_current_analysis?(pattern, analysis) do
        [%__MODULE__{
          type: :generate_alert,
          message: "Historical pattern detected: #{pattern.description}",
          severity: :low,
          priority: 0.5,
          confidence: pattern.confidence
        }]
      else
        []
      end
    end)
  end
  
  # Helper functions for trend analysis
  
  defp trend_indicates_market_shift?(trend) do
    shift_keywords = ["disruption", "transformation", "shift", "change", "revolution"]
    String.downcase(trend) |> contains_any?(shift_keywords)
  end
  
  defp trend_indicates_new_product?(trend) do
    product_keywords = ["launch", "product", "service", "offering", "solution"]
    String.downcase(trend) |> contains_any?(product_keywords)
  end
  
  defp extract_company_from_trend(trend) do
    # Simple extraction - could be enhanced with NLP
    companies = ["BlackRock", "J.P. Morgan", "Goldman Sachs", "Fidelity"]
    
    Enum.find(companies, fn company ->
      String.contains?(String.downcase(trend), String.downcase(company))
    end) || "Unknown"
  end
  
  defp pattern_matches_current_analysis?(pattern, analysis) do
    # Simple pattern matching - could be enhanced with ML
    pattern_keywords = String.split(pattern.description, " ")
    analysis_text = Jason.encode!(analysis)
    
    Enum.any?(pattern_keywords, fn keyword ->
      String.contains?(String.downcase(analysis_text), String.downcase(keyword))
    end)
  end
  
  defp contains_any?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end
end