defmodule DashboardGen.AutonomousAgent.Memory do
  @moduledoc """
  Memory system for the autonomous agent.
  
  Stores and retrieves historical analysis, decisions, and patterns
  to enable learning and improved decision-making over time.
  """
  
  defstruct [
    :analyses,     # List of historical analyses
    :decisions,    # List of decisions made
    :patterns,     # Discovered patterns
    :events,       # Timeline of events
    :created_at
  ]
  
  @max_analyses 50
  @max_decisions 100
  @max_patterns 25
  @max_events 200
  
  @doc "Create new memory instance"
  def new do
    %__MODULE__{
      analyses: [],
      decisions: [],
      patterns: [],
      events: [],
      created_at: DateTime.utc_now()
    }
  end
  
  @doc "Store analysis results in memory"
  def store_analysis(memory, analysis) do
    timestamp = DateTime.utc_now()
    
    analysis_entry = %{
      data: analysis,
      timestamp: timestamp,
      id: generate_id()
    }
    
    # Add to analyses list, keeping only recent ones
    new_analyses = 
      [analysis_entry | memory.analyses]
      |> Enum.take(@max_analyses)
    
    # Add event
    event = %{
      type: :analysis,
      description: "Completed competitive analysis",
      timestamp: timestamp,
      confidence: Map.get(analysis, "confidence_score", 0.5)
    }
    
    new_events = add_event(memory.events, event)
    
    # Look for patterns
    new_patterns = update_patterns(memory.patterns, analysis)
    
    %{memory | 
      analyses: new_analyses,
      events: new_events,
      patterns: new_patterns
    }
  end
  
  @doc "Store decisions in memory"
  def store_decisions(memory, decisions) do
    timestamp = DateTime.utc_now()
    
    decision_entries = 
      Enum.map(decisions, fn decision ->
        %{
          decision: decision,
          timestamp: timestamp,
          id: generate_id(),
          executed: false
        }
      end)
    
    new_decisions = 
      (decision_entries ++ memory.decisions)
      |> Enum.take(@max_decisions)
    
    # Add event
    event = %{
      type: :decisions,
      description: "Made #{length(decisions)} decisions",
      timestamp: timestamp,
      details: decisions
    }
    
    new_events = add_event(memory.events, event)
    
    %{memory | 
      decisions: new_decisions,
      events: new_events
    }
  end
  
  @doc "Get discovered patterns"
  def get_patterns(memory) do
    memory.patterns
  end
  
  @doc "Get recent analyses"
  def get_recent_analyses(memory, limit \\ 10) do
    memory.analyses
    |> Enum.take(limit)
  end
  
  @doc "Get memory summary for context"
  def summary(memory) do
    recent_analyses = length(memory.analyses)
    total_decisions = length(memory.decisions)
    patterns_found = length(memory.patterns)
    
    recent_trends = 
      memory.analyses
      |> Enum.take(5)
      |> Enum.flat_map(&Map.get(&1.data, "trends", []))
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)
      |> Enum.map(&elem(&1, 0))
    
    """
    Memory Summary:
    - #{recent_analyses} analyses stored
    - #{total_decisions} decisions made
    - #{patterns_found} patterns discovered
    - Recent trends: #{Enum.join(recent_trends, ", ")}
    """
  end
  
  @doc "Clean up old data to prevent memory bloat"
  def cleanup_old_data(memory) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)
    
    # Keep only recent data
    new_events = 
      memory.events
      |> Enum.filter(&(DateTime.compare(&1.timestamp, cutoff_date) == :gt))
      |> Enum.take(@max_events)
    
    %{memory | events: new_events}
  end
  
  @doc "Get memory size (for status reporting)"
  def size(memory) do
    %{
      analyses: length(memory.analyses),
      decisions: length(memory.decisions),
      patterns: length(memory.patterns),
      events: length(memory.events)
    }
  end
  
  @doc "Search memory for specific information"
  def search(memory, query) when is_binary(query) do
    query_lower = String.downcase(query)
    
    # Search analyses
    matching_analyses = 
      memory.analyses
      |> Enum.filter(fn analysis ->
        analysis_text = Jason.encode!(analysis.data) |> String.downcase()
        String.contains?(analysis_text, query_lower)
      end)
    
    # Search events
    matching_events = 
      memory.events
      |> Enum.filter(fn event ->
        event_text = event.description |> String.downcase()
        String.contains?(event_text, query_lower)
      end)
    
    %{
      analyses: matching_analyses,
      events: matching_events
    }
  end
  
  ## Private Functions
  
  defp add_event(events, event) do
    [event | events]
    |> Enum.take(@max_events)
  end
  
  defp update_patterns(patterns, analysis) do
    # Extract potential patterns from analysis
    trends = Map.get(analysis, "trends", [])
    opportunities = Map.get(analysis, "opportunities", [])
    
    new_patterns = 
      (trends ++ opportunities)
      |> Enum.map(&extract_pattern/1)
      |> Enum.reject(&is_nil/1)
    
    # Merge with existing patterns, updating frequency
    all_patterns = patterns ++ new_patterns
    
    pattern_groups = 
      all_patterns
      |> Enum.group_by(& &1.description)
      |> Enum.map(fn {description, pattern_list} ->
        frequency = length(pattern_list)
        confidence = min(0.95, frequency * 0.1 + 0.3) # Increase confidence with frequency
        
        %{
          description: description,
          frequency: frequency,
          confidence: confidence,
          last_seen: DateTime.utc_now()
        }
      end)
      |> Enum.sort_by(& &1.frequency, :desc)
      |> Enum.take(@max_patterns)
    
    pattern_groups
  end
  
  defp extract_pattern(text) when is_binary(text) do
    # Simple pattern extraction - look for key phrases
    cond do
      String.contains?(String.downcase(text), "sustainability") ->
        %{description: "ESG/Sustainability Focus", confidence: 0.6}
        
      String.contains?(String.downcase(text), "digital") ->
        %{description: "Digital Transformation", confidence: 0.6}
        
      String.contains?(String.downcase(text), "ai") or String.contains?(String.downcase(text), "artificial intelligence") ->
        %{description: "AI Innovation", confidence: 0.7}
        
      String.contains?(String.downcase(text), "crypto") or String.contains?(String.downcase(text), "blockchain") ->
        %{description: "Crypto/Blockchain", confidence: 0.6}
        
      true -> nil
    end
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end