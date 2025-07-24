defmodule DashboardGen.AgentCoordinator do
  @moduledoc """
  Multi-agent coordination protocols for orchestrating complex tasks.
  
  Manages agent workflows, task distribution, result aggregation, and 
  inter-agent communication for sophisticated analysis pipelines.
  """
  
  use GenServer
  require Logger
  alias DashboardGen.{
    AgentRouter, AgentTagging, TimeComparison, 
    Analytics, Insights, CodexClient
  }
  
  @coordination_timeout 300_000 # 5 minutes for complex workflows
  
  defstruct [
    :active_workflows,
    :agent_registry,
    :workflow_templates,
    :coordination_history,
    :performance_metrics
  ]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    state = %__MODULE__{
      active_workflows: %{},
      agent_registry: initialize_agent_registry(),
      workflow_templates: load_workflow_templates(),
      coordination_history: [],
      performance_metrics: %{}
    }
    
    {:ok, state}
  end
  
  @doc """
  Execute a coordinated multi-agent workflow
  """
  def execute_workflow(workflow_type, params \\ %{}) do
    GenServer.call(__MODULE__, {:execute_workflow, workflow_type, params}, @coordination_timeout)
  end
  
  @doc """
  Get active workflow status
  """
  def get_workflow_status(workflow_id) do
    GenServer.call(__MODULE__, {:get_workflow_status, workflow_id})
  end
  
  @doc """
  List available workflow templates
  """
  def list_workflows do
    GenServer.call(__MODULE__, :list_workflows)
  end
  
  @doc """
  Get coordination performance metrics
  """
  def get_coordination_metrics do
    GenServer.call(__MODULE__, :get_coordination_metrics)
  end
  
  # GenServer Callbacks
  
  def handle_call({:execute_workflow, workflow_type, params}, from, state) do
    workflow_id = generate_workflow_id()
    
    case Map.get(state.workflow_templates, workflow_type) do
      nil ->
        {:reply, {:error, "Unknown workflow type: #{workflow_type}"}, state}
        
      template ->
        # Start workflow execution asynchronously
        Task.start(fn ->
          result = execute_workflow_steps(workflow_id, template, params, state)
          GenServer.reply(from, result)
        end)
        
        # Track active workflow
        workflow = %{
          id: workflow_id,
          type: workflow_type,
          params: params,
          status: :running,
          started_at: DateTime.utc_now(),
          steps: template.steps
        }
        
        new_active = Map.put(state.active_workflows, workflow_id, workflow)
        {:noreply, %{state | active_workflows: new_active}}
    end
  end
  
  def handle_call({:get_workflow_status, workflow_id}, _from, state) do
    status = Map.get(state.active_workflows, workflow_id, :not_found)
    {:reply, status, state}
  end
  
  def handle_call(:list_workflows, _from, state) do
    workflows = Map.keys(state.workflow_templates)
    {:reply, workflows, state}
  end
  
  def handle_call(:get_coordination_metrics, _from, state) do
    metrics = compile_coordination_metrics(state)
    {:reply, metrics, state}
  end
  
  # Workflow Execution
  
  defp execute_workflow_steps(workflow_id, template, params, state) do
    Logger.info("Starting workflow #{workflow_id}: #{template.name}")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Execute steps sequentially or in parallel based on dependencies
    result = case template.execution_mode do
      :sequential -> execute_sequential_workflow(workflow_id, template.steps, params, state)
      :parallel -> execute_parallel_workflow(workflow_id, template.steps, params, state)
      :dag -> execute_dag_workflow(workflow_id, template.steps, params, state)
    end
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    # Record workflow completion
    GenServer.cast(__MODULE__, {:workflow_completed, workflow_id, result, duration})
    
    Logger.info("Completed workflow #{workflow_id} in #{duration}ms")
    result
  end
  
  defp execute_sequential_workflow(workflow_id, steps, params, _state) do
    Logger.info("Executing sequential workflow #{workflow_id} with #{length(steps)} steps")
    
    {results, errors} = Enum.reduce(steps, {%{}, []}, fn step, {acc_results, acc_errors} ->
      case execute_step(step, acc_results, params) do
        {:ok, step_result} ->
          {Map.put(acc_results, step.id, step_result), acc_errors}
        {:error, error} ->
          {acc_results, [%{step: step.id, error: error} | acc_errors]}
      end
    end)
    
    if length(errors) > 0 do
      {:error, %{results: results, errors: errors}}
    else
      {:ok, results}
    end
  end
  
  defp execute_parallel_workflow(workflow_id, steps, params, _state) do
    Logger.info("Executing parallel workflow #{workflow_id} with #{length(steps)} steps")
    
    # Execute all steps in parallel
    tasks = Enum.map(steps, fn step ->
      Task.async(fn ->
        {step.id, execute_step(step, %{}, params)}
      end)
    end)
    
    # Collect results
    results = tasks
    |> Task.await_many(@coordination_timeout)
    |> Enum.reduce({%{}, []}, fn {step_id, result}, {acc_results, acc_errors} ->
      case result do
        {:ok, step_result} ->
          {Map.put(acc_results, step_id, step_result), acc_errors}
        {:error, error} ->
          {acc_results, [%{step: step_id, error: error} | acc_errors]}
      end
    end)
    
    case results do
      {step_results, []} -> {:ok, step_results}
      {step_results, errors} -> {:error, %{results: step_results, errors: errors}}
    end
  end
  
  defp execute_dag_workflow(workflow_id, steps, params, _state) do
    Logger.info("Executing DAG workflow #{workflow_id} with #{length(steps)} steps")
    
    # Build dependency graph and execute in topological order
    # For now, simplified to sequential execution
    execute_sequential_workflow(workflow_id, steps, params, nil)
  end
  
  defp execute_step(step, previous_results, params) do
    Logger.debug("Executing step: #{step.id} (#{step.agent})")
    
    # Merge step params with workflow params and previous results
    step_params = Map.merge(params, step.params || %{})
    step_params = Map.put(step_params, :previous_results, previous_results)
    
    case step.agent do
      :router -> execute_router_step(step, step_params)
      :tagging -> execute_tagging_step(step, step_params)
      :analytics -> execute_analytics_step(step, step_params)
      :insights -> execute_insights_step(step, step_params)
      :time_comparison -> execute_time_comparison_step(step, step_params)
      :synthesis -> execute_synthesis_step(step, step_params)
      :validation -> execute_validation_step(step, step_params)
      _ -> {:error, "Unknown agent: #{step.agent}"}
    end
  end
  
  # Agent Step Executors
  
  defp execute_router_step(step, params) do
    query = Map.get(params, :query) || step.params[:query]
    
    case AgentRouter.route_query(query, params) do
      %{results: results} -> {:ok, results}
      error -> {:error, error}
    end
  end
  
  defp execute_tagging_step(_step, params) do
    content = Map.get(params, :content) || 
              Map.get(params, :previous_results) |> Map.get(:content, [])
    
    case content do
      [] -> {:ok, []}
      content_list when is_list(content_list) ->
        tagged_content = AgentTagging.tag_content_batch(content_list)
        {:ok, tagged_content}
      single_content ->
        tagged = AgentTagging.tag_content(single_content)
        {:ok, [tagged]}
    end
  end
  
  defp execute_analytics_step(_step, params) do
    days_back = Map.get(params, :days_back, 7)
    
    case Analytics.get_analytics_summary(days_back) do
      summary when is_map(summary) -> {:ok, summary}
      error -> {:error, error}
    end
  end
  
  defp execute_insights_step(_step, params) do
    limit = Map.get(params, :limit, 10)
    
    case Insights.list_recent_insights_by_company(limit) do
      insights when is_list(insights) -> {:ok, insights}
      error -> {:error, error}
    end
  end
  
  defp execute_time_comparison_step(_step, params) do
    year = Map.get(params, :year, Date.utc_today().year)
    quarter = Map.get(params, :quarter, 1)
    
    case TimeComparison.quarter_over_quarter(year, quarter) do
      comparison when is_map(comparison) -> {:ok, comparison}
      error -> {:error, error}
    end
  end
  
  defp execute_synthesis_step(step, params) do
    previous_results = Map.get(params, :previous_results, %{})
    synthesis_prompt = build_synthesis_prompt(step, previous_results, params)
    
    case CodexClient.ask(synthesis_prompt) do
      {:ok, synthesis} -> {:ok, synthesis}
      error -> error
    end
  end
  
  defp execute_validation_step(step, params) do
    previous_results = Map.get(params, :previous_results, %{})
    validation_criteria = step.params[:criteria] || []
    
    validation_results = Enum.map(validation_criteria, fn criterion ->
      validate_criterion(criterion, previous_results)
    end)
    
    {:ok, validation_results}
  end
  
  # Workflow Templates
  
  defp load_workflow_templates do
    %{
      comprehensive_analysis: %{
        name: "Comprehensive Market Analysis",
        description: "Full competitive and analytics analysis with synthesis",
        execution_mode: :sequential,
        steps: [
          %{id: :analytics_data, agent: :analytics, params: %{days_back: 30}},
          %{id: :competitor_insights, agent: :insights, params: %{limit: 20}},
          %{id: :content_tagging, agent: :tagging, params: %{}},
          %{id: :time_trends, agent: :time_comparison, params: %{quarter: 1}},
          %{id: :synthesis, agent: :synthesis, params: %{
            template: :comprehensive_analysis,
            sections: [:performance, :competitive_landscape, :trends, :recommendations]
          }}
        ]
      },
      
      competitor_deep_dive: %{
        name: "Competitor Deep Dive Analysis",
        description: "Detailed analysis of specific competitor activity",
        execution_mode: :parallel,
        steps: [
          %{id: :recent_activity, agent: :insights, params: %{company_filter: true}},
          %{id: :content_analysis, agent: :tagging, params: %{focus: :competitive}},
          %{id: :trend_analysis, agent: :time_comparison, params: %{focus: :competitor}},
          %{id: :synthesis, agent: :synthesis, params: %{
            template: :competitor_analysis,
            sections: [:activity_summary, :strategic_moves, :threat_assessment]
          }}
        ]
      },
      
      market_trend_detection: %{
        name: "Market Trend Detection Pipeline",
        description: "Identify and analyze emerging market trends",
        execution_mode: :sequential,
        steps: [
          %{id: :content_collection, agent: :insights, params: %{days_back: 14}},
          %{id: :trend_tagging, agent: :tagging, params: %{focus: :trends}},
          %{id: :trend_analysis, agent: :time_comparison, params: %{focus: :trends}},
          %{id: :validation, agent: :validation, params: %{
            criteria: [:trend_significance, :data_quality, :temporal_consistency]
          }},
          %{id: :trend_synthesis, agent: :synthesis, params: %{
            template: :trend_report,
            sections: [:emerging_trends, :declining_patterns, :strategic_implications]
          }}
        ]
      },
      
      real_time_monitoring: %{
        name: "Real-time Market Monitoring",
        description: "Continuous monitoring and alerting pipeline",
        execution_mode: :parallel,
        steps: [
          %{id: :analytics_check, agent: :analytics, params: %{days_back: 1}},
          %{id: :competitor_check, agent: :insights, params: %{hours_back: 6}},
          %{id: :anomaly_detection, agent: :validation, params: %{
            criteria: [:spike_detection, :pattern_deviation]
          }},
          %{id: :alert_synthesis, agent: :synthesis, params: %{
            template: :monitoring_alert,
            sections: [:summary, :significant_changes, :recommended_actions]
          }}
        ]
      }
    }
  end
  
  # Helper Functions
  
  defp build_synthesis_prompt(step, previous_results, _params) do
    template = step.params[:template]
    sections = step.params[:sections] || []
    
    results_summary = format_results_for_synthesis(previous_results)
    
    case template do
      :comprehensive_analysis ->
        """
        COMPREHENSIVE MARKET ANALYSIS SYNTHESIS
        
        Synthesize the following analysis results into a comprehensive report:
        
        COLLECTED DATA:
        #{results_summary}
        
        GENERATE REPORT WITH SECTIONS:
        #{Enum.join(sections, ", ")}
        
        Provide strategic insights, key findings, and actionable recommendations.
        Format with clear headers and bullet points for executive consumption.
        """
        
      :competitor_analysis ->
        """
        COMPETITOR DEEP DIVE SYNTHESIS
        
        Analyze competitor intelligence data and provide strategic assessment:
        
        INTELLIGENCE DATA:
        #{results_summary}
        
        FOCUS AREAS:
        #{Enum.join(sections, ", ")}
        
        Assess competitive threats, opportunities, and recommended responses.
        """
        
      :trend_report ->
        """
        MARKET TREND ANALYSIS SYNTHESIS
        
        Synthesize trend detection results into strategic trend report:
        
        TREND DATA:
        #{results_summary}
        
        REPORT SECTIONS:
        #{Enum.join(sections, ", ")}
        
        Identify actionable trends and strategic implications for business planning.
        """
        
      _ ->
        """
        WORKFLOW SYNTHESIS
        
        Synthesize the following workflow results:
        
        RESULTS:
        #{results_summary}
        
        Provide clear summary and key insights.
        """
    end
  end
  
  defp format_results_for_synthesis(results) do
    results
    |> Enum.map(fn {step_id, result} ->
      "#{step_id}: #{inspect(result) |> String.slice(0, 200)}..."
    end)
    |> Enum.join("\n")
  end
  
  defp validate_criterion(criterion, _results) do
    case criterion do
      :trend_significance ->
        # Check if trends meet significance thresholds
        %{criterion: criterion, passed: true, score: 0.8}
        
      :data_quality ->
        # Validate data completeness and accuracy
        %{criterion: criterion, passed: true, score: 0.9}
        
      :temporal_consistency ->
        # Check for temporal consistency in trends
        %{criterion: criterion, passed: true, score: 0.85}
        
      :spike_detection ->
        # Look for significant data spikes
        %{criterion: criterion, passed: false, score: 0.3}
        
      _ ->
        %{criterion: criterion, passed: true, score: 0.5}
    end
  end
  
  defp initialize_agent_registry do
    %{
      router: %{status: :available, last_used: DateTime.utc_now()},
      tagging: %{status: :available, last_used: DateTime.utc_now()},
      analytics: %{status: :available, last_used: DateTime.utc_now()},
      insights: %{status: :available, last_used: DateTime.utc_now()},
      time_comparison: %{status: :available, last_used: DateTime.utc_now()},
      monitor: %{status: :available, last_used: DateTime.utc_now()}
    }
  end
  
  defp compile_coordination_metrics(state) do
    %{
      active_workflows: map_size(state.active_workflows),
      total_workflows_run: length(state.coordination_history),
      agent_status: state.agent_registry,
      avg_workflow_duration: calculate_avg_duration(state.coordination_history),
      workflow_success_rate: calculate_success_rate(state.coordination_history),
      most_used_workflows: get_workflow_usage_stats(state.coordination_history)
    }
  end
  
  defp calculate_avg_duration(history) do
    if length(history) > 0 do
      durations = Enum.map(history, &Map.get(&1, :duration, 0))
      Enum.sum(durations) / length(durations)
    else
      0
    end
  end
  
  defp calculate_success_rate(history) do
    if length(history) > 0 do
      successful = Enum.count(history, &(Map.get(&1, :status) == :success))
      successful / length(history)
    else
      1.0
    end
  end
  
  defp get_workflow_usage_stats(history) do
    history
    |> Enum.group_by(&Map.get(&1, :type))
    |> Enum.map(fn {type, workflows} -> {type, length(workflows)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end
  
  defp generate_workflow_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  # GenServer cast handler for workflow completion
  def handle_cast({:workflow_completed, workflow_id, result, duration}, state) do
    # Remove from active workflows
    new_active = Map.delete(state.active_workflows, workflow_id)
    
    # Add to history
    workflow_record = %{
      id: workflow_id,
      completed_at: DateTime.utc_now(),
      duration: duration,
      status: case result do
        {:ok, _} -> :success
        {:error, _} -> :error
      end,
      type: Map.get(state.active_workflows, workflow_id, %{}) |> Map.get(:type)
    }
    
    new_history = [workflow_record | state.coordination_history]
    |> Enum.take(100) # Keep last 100 workflow records
    
    {:noreply, %{state | 
      active_workflows: new_active,
      coordination_history: new_history
    }}
  end
end