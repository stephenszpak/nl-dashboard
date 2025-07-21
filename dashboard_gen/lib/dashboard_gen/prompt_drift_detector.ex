defmodule DashboardGen.PromptDriftDetector do
  @moduledoc """
  Advanced prompt drift detection system.
  
  Monitors AI response quality, consistency, and adherence to expected formats.
  Detects when prompts are becoming less effective and suggests optimizations.
  """
  
  use GenServer
  require Logger
  alias DashboardGen.{CodexClient, AlertStore}
  
  @check_interval :timer.minutes(30) # Check every 30 minutes
  @sample_size 20 # Number of recent responses to analyze
  @drift_threshold 0.3 # 30% degradation triggers alert
  
  defstruct [
    :baseline_metrics,
    :recent_responses,
    :drift_history,
    :prompt_templates,
    :performance_targets,
    :last_analysis
  ]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_analysis()
    
    state = %__MODULE__{
      baseline_metrics: %{},
      recent_responses: [],
      drift_history: [],
      prompt_templates: load_prompt_templates(),
      performance_targets: load_performance_targets(),
      last_analysis: DateTime.utc_now()
    }
    
    {:ok, state}
  end
  
  @doc """
  Record a prompt-response pair for drift analysis
  """
  def record_interaction(prompt, response, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_interaction, prompt, response, metadata})
  end
  
  @doc """
  Get current drift analysis
  """
  def get_drift_analysis do
    GenServer.call(__MODULE__, :get_drift_analysis)
  end
  
  @doc """
  Get prompt optimization suggestions
  """
  def get_optimization_suggestions do
    GenServer.call(__MODULE__, :get_optimization_suggestions)
  end
  
  @doc """
  Manually trigger drift analysis
  """
  def analyze_drift do
    GenServer.cast(__MODULE__, :analyze_drift)
  end
  
  # GenServer Callbacks
  
  def handle_info(:analyze_drift, state) do
    new_state = perform_drift_analysis(state)
    schedule_analysis()
    {:noreply, new_state}
  end
  
  def handle_cast({:record_interaction, prompt, response, metadata}, state) do
    interaction = %{
      prompt: prompt,
      response: response,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      metrics: calculate_response_metrics(prompt, response, metadata)
    }
    
    new_responses = [interaction | state.recent_responses]
    |> Enum.take(@sample_size) # Keep only recent samples
    
    {:noreply, %{state | recent_responses: new_responses}}
  end
  
  def handle_cast(:analyze_drift, state) do
    new_state = perform_drift_analysis(state)
    {:noreply, new_state}
  end
  
  def handle_call(:get_drift_analysis, _from, state) do
    analysis = compile_drift_analysis(state)
    {:reply, analysis, state}
  end
  
  def handle_call(:get_optimization_suggestions, _from, state) do
    suggestions = generate_optimization_suggestions(state)
    {:reply, suggestions, state}
  end
  
  # Analysis Functions
  
  defp perform_drift_analysis(state) do
    if length(state.recent_responses) >= 5 do
      Logger.info("Performing prompt drift analysis...")
      
      current_metrics = calculate_aggregate_metrics(state.recent_responses)
      baseline_metrics = state.baseline_metrics
      
      # Initialize baseline if empty
      baseline_metrics = if baseline_metrics == %{} do
        current_metrics
      else
        baseline_metrics
      end
      
      drift_detection = detect_drift(current_metrics, baseline_metrics)
      
      # Record drift history
      drift_entry = %{
        timestamp: DateTime.utc_now(),
        current_metrics: current_metrics,
        baseline_metrics: baseline_metrics,
        drift_score: drift_detection.overall_drift,
        issues: drift_detection.issues
      }
      
      new_drift_history = [drift_entry | state.drift_history]
      |> Enum.take(100) # Keep last 100 analyses
      
      # Alert on significant drift
      if drift_detection.overall_drift > @drift_threshold do
        send_drift_alert(drift_detection)
      end
      
      # Update baseline periodically (every 50 samples)
      new_baseline = if rem(length(state.recent_responses), 50) == 0 do
        current_metrics
      else
        baseline_metrics
      end
      
      %{state |
        baseline_metrics: new_baseline,
        drift_history: new_drift_history,
        last_analysis: DateTime.utc_now()
      }
    else
      state
    end
  end
  
  defp calculate_response_metrics(prompt, response, metadata) do
    %{
      response_length: String.length(response),
      word_count: length(String.split(response)),
      structure_score: analyze_response_structure(response),
      relevance_score: analyze_relevance(prompt, response),
      format_adherence: check_format_adherence(response, metadata),
      confidence_indicators: extract_confidence_indicators(response),
      error_indicators: detect_error_indicators(response),
      processing_time: Map.get(metadata, :processing_time, 0)
    }
  end
  
  defp calculate_aggregate_metrics(responses) do
    metrics_list = Enum.map(responses, & &1.metrics)
    
    %{
      avg_response_length: calculate_average(metrics_list, :response_length),
      avg_word_count: calculate_average(metrics_list, :word_count),
      avg_structure_score: calculate_average(metrics_list, :structure_score),
      avg_relevance_score: calculate_average(metrics_list, :relevance_score),
      avg_format_adherence: calculate_average(metrics_list, :format_adherence),
      avg_processing_time: calculate_average(metrics_list, :processing_time),
      error_rate: calculate_error_rate(metrics_list),
      confidence_trend: calculate_confidence_trend(metrics_list)
    }
  end
  
  defp detect_drift(current, baseline) do
    issues = []
    
    # Check response length drift
    length_drift = calculate_drift_percentage(current.avg_response_length, baseline.avg_response_length)
    issues = if abs(length_drift) > 0.5 do
      [%{type: :response_length, drift: length_drift, threshold: 0.5} | issues]
    else
      issues
    end
    
    # Check structure quality drift
    structure_drift = calculate_drift_percentage(current.avg_structure_score, baseline.avg_structure_score)
    issues = if structure_drift < -0.2 do # 20% decrease in structure quality
      [%{type: :structure_quality, drift: structure_drift, threshold: -0.2} | issues]
    else
      issues
    end
    
    # Check relevance drift
    relevance_drift = calculate_drift_percentage(current.avg_relevance_score, baseline.avg_relevance_score)
    issues = if relevance_drift < -0.25 do # 25% decrease in relevance
      [%{type: :relevance, drift: relevance_drift, threshold: -0.25} | issues]
    else
      issues
    end
    
    # Check error rate increase
    error_drift = current.error_rate - baseline.error_rate
    issues = if error_drift > 0.1 do # 10% increase in errors
      [%{type: :error_rate, drift: error_drift, threshold: 0.1} | issues]
    else
      issues
    end
    
    # Check processing time drift
    time_drift = calculate_drift_percentage(current.avg_processing_time, baseline.avg_processing_time)
    issues = if time_drift > 0.5 do # 50% increase in processing time
      [%{type: :processing_time, drift: time_drift, threshold: 0.5} | issues]
    else
      issues
    end
    
    overall_drift = if length(issues) > 0 do
      drift_values = Enum.map(issues, &abs(&1.drift))
      Enum.sum(drift_values) / length(issues)
    else
      0
    end
    
    %{
      overall_drift: overall_drift,
      issues: issues,
      severity: determine_drift_severity(overall_drift, issues)
    }
  end
  
  # Analysis Helper Functions
  
  defp analyze_response_structure(response) do
    # Check for structured elements like headers, bullet points, sections
    structure_indicators = [
      String.contains?(response, ["##", "###"]), # Headers
      String.contains?(response, ["- ", "* ", "• "]), # Bullet points
      String.contains?(response, ["\n1.", "\n2.", "\n3."]), # Numbered lists
      String.contains?(response, [":", "\n\n"]), # Sections and breaks
    ]
    
    Enum.count(structure_indicators, & &1) / length(structure_indicators)
  end
  
  defp analyze_relevance(prompt, response) do
    # Simple keyword overlap analysis
    prompt_words = prompt |> String.downcase() |> String.split() |> Enum.filter(&(String.length(&1) > 3))
    response_words = response |> String.downcase() |> String.split() |> Enum.filter(&(String.length(&1) > 3))
    
    overlap = MapSet.intersection(MapSet.new(prompt_words), MapSet.new(response_words))
    
    if length(prompt_words) > 0 do
      MapSet.size(overlap) / length(prompt_words)
    else
      0.5
    end
  end
  
  defp check_format_adherence(response, metadata) do
    expected_format = Map.get(metadata, :expected_format, :any)
    
    case expected_format do
      :structured ->
        if String.contains?(response, ["TOPICS:", "SENTIMENT:", "INSIGHTS:"]) do
          1.0
        else
          0.0
        end
      :json ->
        case Jason.decode(response) do
          {:ok, _} -> 1.0
          {:error, _} -> 0.0
        end
      _ -> 0.5 # Unknown format, assume partial compliance
    end
  end
  
  defp extract_confidence_indicators(response) do
    confidence_words = ["likely", "probably", "possibly", "might", "could", "uncertain", "unclear"]
    uncertainty_count = confidence_words
    |> Enum.map(&String.contains?(String.downcase(response), &1))
    |> Enum.count(& &1)
    
    # Higher uncertainty count = lower confidence
    max(0, 1.0 - (uncertainty_count / 10))
  end
  
  defp detect_error_indicators(response) do
    error_indicators = [
      String.contains?(response, ["error", "failed", "unable", "cannot"]),
      String.contains?(response, ["sorry", "apologize", "don't know"]),
      String.length(response) < 10, # Very short responses
      String.contains?(response, ["```", "ERROR", "Exception"]) # Code errors
    ]
    
    Enum.count(error_indicators, & &1) > 0
  end
  
  defp calculate_average(metrics_list, field) do
    values = Enum.map(metrics_list, &Map.get(&1, field, 0))
    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0
    end
  end
  
  defp calculate_error_rate(metrics_list) do
    error_count = Enum.count(metrics_list, &Map.get(&1, :error_indicators, false))
    if length(metrics_list) > 0 do
      error_count / length(metrics_list)
    else
      0
    end
  end
  
  defp calculate_confidence_trend(metrics_list) do
    confidences = Enum.map(metrics_list, &Map.get(&1, :confidence_indicators, 0.5))
    if length(confidences) > 1 do
      # Simple trend: compare first and last half
      mid_point = div(length(confidences), 2)
      first_half = Enum.take(confidences, mid_point)
      second_half = Enum.drop(confidences, mid_point)
      
      avg_first = Enum.sum(first_half) / length(first_half)
      avg_second = Enum.sum(second_half) / length(second_half)
      
      avg_second - avg_first # Positive = improving confidence
    else
      0
    end
  end
  
  defp calculate_drift_percentage(current, baseline) when baseline > 0 do
    (current - baseline) / baseline
  end
  defp calculate_drift_percentage(_, _), do: 0
  
  defp determine_drift_severity(overall_drift, issues) do
    cond do
      overall_drift > 0.5 or length(issues) > 3 -> :critical
      overall_drift > 0.3 or length(issues) > 2 -> :high
      overall_drift > 0.1 or length(issues) > 0 -> :medium
      true -> :low
    end
  end
  
  # Notification and Optimization
  
  defp send_drift_alert(drift_detection) do
    AlertStore.store_alert(%{
      id: generate_alert_id(),
      type: :prompt_drift,
      severity: drift_detection.severity,
      title: "Prompt Drift Detected",
      message: format_drift_alert_message(drift_detection),
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      metadata: drift_detection
    })
  end
  
  defp format_drift_alert_message(drift_detection) do
    issues_text = drift_detection.issues
    |> Enum.map(&"- #{&1.type}: #{Float.round(&1.drift * 100, 1)}% change")
    |> Enum.join("\n")
    
    """
    🚨 PROMPT DRIFT DETECTED
    
    Overall Drift Score: #{Float.round(drift_detection.overall_drift * 100, 1)}%
    Severity: #{String.upcase(to_string(drift_detection.severity))}
    
    Issues Detected:
    #{issues_text}
    
    💡 Recommended Actions:
    - Review recent prompt templates for effectiveness
    - Consider prompt optimization or model fine-tuning
    - Check for changes in data quality or format
    """
  end
  
  defp generate_optimization_suggestions(state) do
    if length(state.drift_history) > 0 do
      latest_analysis = List.first(state.drift_history)
      
      suggestions = []
      
      # Analyze each issue type and suggest fixes
      suggestions = Enum.reduce(latest_analysis.issues, suggestions, fn issue, acc ->
        suggestion = case issue.type do
          :response_length ->
            if issue.drift > 0 do
              "Consider adding length constraints to prompts (responses are getting too long)"
            else
              "Consider asking for more detailed responses (responses are getting too short)"
            end
            
          :structure_quality ->
            "Add more explicit formatting instructions to prompts (e.g., 'Use bullet points', 'Include headers')"
            
          :relevance ->
            "Improve prompt specificity and add context examples to increase relevance"
            
          :error_rate ->
            "Review prompts for ambiguity and add error handling instructions"
            
          :processing_time ->
            "Consider simplifying prompts or using smaller models for faster responses"
            
          _ ->
            "Review and optimize prompt template for this issue type"
        end
        
        [%{issue_type: issue.type, suggestion: suggestion, priority: issue.drift} | acc]
      end)
      
      # Add general suggestions based on trends
      if latest_analysis.drift_score > 0.2 do
        suggestions = [
          %{
            issue_type: :general,
            suggestion: "Consider establishing new baseline metrics - current patterns may reflect system evolution",
            priority: 0.5
          } | suggestions
        ]
      end
      
      suggestions
    else
      []
    end
  end
  
  defp compile_drift_analysis(state) do
    %{
      last_analysis: state.last_analysis,
      baseline_established: state.baseline_metrics != %{},
      recent_samples: length(state.recent_responses),
      drift_history: Enum.take(state.drift_history, 10),
      current_status: if length(state.drift_history) > 0 do
        List.first(state.drift_history).drift_score
      else
        0
      end,
      optimization_suggestions: generate_optimization_suggestions(state)
    }
  end
  
  # Helper Functions
  
  defp schedule_analysis do
    Process.send_after(self(), :analyze_drift, @check_interval)
  end
  
  defp load_prompt_templates do
    # Load prompt templates from configuration or database
    %{
      content_tagging: "Analyze and tag content...",
      competitive_analysis: "Analyze competitive intelligence...",
      trend_analysis: "Detect trends in data..."
    }
  end
  
  defp load_performance_targets do
    %{
      structure_score: 0.7,
      relevance_score: 0.8,
      format_adherence: 0.9,
      error_rate: 0.05,
      confidence_score: 0.7
    }
  end
  
  defp generate_alert_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end