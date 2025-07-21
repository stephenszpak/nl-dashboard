defmodule DashboardGen.AgentMonitor do
  @moduledoc """
  Agent self-monitoring and uptime reporting system.
  
  Tracks agent performance, system health, scraper success rates,
  and provides comprehensive uptime and performance reporting.
  """
  
  use GenServer
  alias DashboardGen.{CodexClient, AlertStore}
  require Logger
  
  @monitor_interval :timer.minutes(5) # Check every 5 minutes
  @health_check_timeout 30_000 # 30 seconds
  @performance_window_hours 24
  
  defstruct [
    :start_time,
    :last_health_check,
    :total_requests,
    :successful_requests,
    :failed_requests,
    :average_response_time,
    :system_metrics,
    :agent_status,
    :error_log,
    :performance_history
  ]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_monitoring()
    
    initial_state = %__MODULE__{
      start_time: DateTime.utc_now(),
      last_health_check: DateTime.utc_now(),
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      average_response_time: 0.0,
      system_metrics: %{},
      agent_status: %{},
      error_log: [],
      performance_history: []
    }
    
    {:ok, initial_state}
  end
  
  @doc """
  Get current system health status
  """
  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end
  
  @doc """
  Get performance metrics
  """
  def get_performance_metrics do
    GenServer.call(__MODULE__, :get_performance_metrics)
  end
  
  @doc """
  Get uptime report
  """
  def get_uptime_report do
    GenServer.call(__MODULE__, :get_uptime_report)
  end
  
  @doc """
  Record a request for monitoring
  """
  def record_request(type, duration_ms, result) do
    GenServer.cast(__MODULE__, {:record_request, type, duration_ms, result})
  end
  
  @doc """
  Record an error for monitoring
  """
  def record_error(type, error, context \\ %{}) do
    GenServer.cast(__MODULE__, {:record_error, type, error, context})
  end
  
  # GenServer Callbacks
  
  def handle_info(:perform_monitoring, state) do
    new_state = perform_health_checks(state)
    schedule_monitoring()
    {:noreply, new_state}
  end
  
  def handle_call(:get_health_status, _from, state) do
    health_status = compile_health_status(state)
    {:reply, health_status, state}
  end
  
  def handle_call(:get_performance_metrics, _from, state) do
    metrics = compile_performance_metrics(state)
    {:reply, metrics, state}
  end
  
  def handle_call(:get_uptime_report, _from, state) do
    report = generate_uptime_report(state)
    {:reply, report, state}
  end
  
  def handle_cast({:record_request, type, duration_ms, result}, state) do
    new_state = update_request_metrics(state, type, duration_ms, result)
    {:noreply, new_state}
  end
  
  def handle_cast({:record_error, type, error, context}, state) do
    new_state = log_error(state, type, error, context)
    {:noreply, new_state}
  end
  
  # Monitoring Functions
  
  defp schedule_monitoring do
    Process.send_after(self(), :perform_monitoring, @monitor_interval)
  end
  
  defp perform_health_checks(state) do
    Logger.info("Performing agent health checks...")
    
    new_state = state
    |> check_system_resources()
    |> check_agent_components()
    |> check_external_dependencies()
    |> update_performance_history()
    |> Map.put(:last_health_check, DateTime.utc_now())
    
    # Alert on critical issues
    check_for_critical_issues(new_state)
    
    new_state
  end
  
  defp check_system_resources(state) do
    try do
      system_metrics = %{
        memory_usage: get_memory_usage(),
        cpu_usage: get_cpu_usage(),
        disk_usage: get_disk_usage(),
        process_count: get_process_count(),
        uptime: calculate_uptime(state.start_time)
      }
      
      %{state | system_metrics: system_metrics}
    rescue
      error ->
        Logger.error("Failed to collect system metrics: #{inspect(error)}")
        state
    end
  end
  
  defp check_agent_components(state) do
    components = [
      {:agent_triggers, &check_agent_triggers/0},
      {:alert_store, &check_alert_store/0},
      {:planning_agents, &check_planning_agents/0},
      {:analytics_connector, &check_analytics_connector/0},
      {:insights_connector, &check_insights_connector/0},
      {:codex_client, &check_codex_client/0}
    ]
    
    agent_status = Enum.reduce(components, %{}, fn {component, check_fn}, acc ->
      status = try do
        check_fn.()
      rescue
        error ->
          Logger.warn("Health check failed for #{component}: #{inspect(error)}")
          %{status: :error, error: inspect(error), checked_at: DateTime.utc_now()}
      end
      
      Map.put(acc, component, status)
    end)
    
    %{state | agent_status: agent_status}
  end
  
  defp check_external_dependencies(state) do
    # Check external APIs and services
    dependencies = [
      {:openai_api, &check_openai_api/0},
      {:database, &check_database_connection/0}
    ]
    
    dependency_status = Enum.reduce(dependencies, %{}, fn {dep, check_fn}, acc ->
      status = try do
        {time_us, result} = :timer.tc(check_fn)
        case result do
          :ok -> %{status: :healthy, response_time_ms: time_us / 1000, checked_at: DateTime.utc_now()}
          {:error, reason} -> %{status: :error, error: reason, checked_at: DateTime.utc_now()}
        end
      rescue
        error ->
          %{status: :error, error: inspect(error), checked_at: DateTime.utc_now()}
      end
      
      Map.put(acc, dep, status)
    end)
    
    current_system = Map.get(state.system_metrics, :dependencies, %{})
    updated_system = Map.put(state.system_metrics, :dependencies, dependency_status)
    
    %{state | system_metrics: updated_system}
  end
  
  defp update_performance_history(state) do
    current_performance = %{
      timestamp: DateTime.utc_now(),
      total_requests: state.total_requests,
      success_rate: calculate_success_rate(state),
      average_response_time: state.average_response_time,
      memory_usage: Map.get(state.system_metrics, :memory_usage, 0),
      cpu_usage: Map.get(state.system_metrics, :cpu_usage, 0)
    }
    
    # Keep last 24 hours of history (288 data points at 5-minute intervals)
    max_history_points = 288
    new_history = [current_performance | state.performance_history]
    |> Enum.take(max_history_points)
    
    %{state | performance_history: new_history}
  end
  
  defp check_for_critical_issues(state) do
    issues = []
    
    # Check success rate
    success_rate = calculate_success_rate(state)
    if success_rate < 0.8 and state.total_requests > 10 do
      issues = [%{type: :low_success_rate, value: success_rate, threshold: 0.8} | issues]
    end
    
    # Check memory usage
    memory_usage = Map.get(state.system_metrics, :memory_usage, 0)
    if memory_usage > 0.9 do
      issues = [%{type: :high_memory_usage, value: memory_usage, threshold: 0.9} | issues]
    end
    
    # Check response time
    if state.average_response_time > 10000 do # 10 seconds
      issues = [%{type: :slow_response_time, value: state.average_response_time, threshold: 10000} | issues]
    end
    
    # Alert on critical issues
    Enum.each(issues, &send_critical_alert/1)
  end
  
  # Health Check Functions
  
  defp check_agent_triggers do
    case Process.whereis(DashboardGen.AgentTriggers) do
      nil -> %{status: :not_running, checked_at: DateTime.utc_now()}
      _pid -> %{status: :healthy, checked_at: DateTime.utc_now()}
    end
  end
  
  defp check_alert_store do
    case GenServer.call(DashboardGen.AlertStore, :get_alert_stats, 5000) do
      %{} -> %{status: :healthy, checked_at: DateTime.utc_now()}
      _ -> %{status: :error, error: "Invalid response", checked_at: DateTime.utc_now()}
    end
  end
  
  defp check_planning_agents do
    case Process.whereis(DashboardGen.PlanningAgents) do
      nil -> %{status: :not_running, checked_at: DateTime.utc_now()}
      _pid -> %{status: :healthy, checked_at: DateTime.utc_now()}
    end
  end
  
  defp check_analytics_connector do
    # Test analytics query
    case DashboardGen.Analytics.get_analytics_summary(1) do
      %{} -> %{status: :healthy, checked_at: DateTime.utc_now()}
      _ -> %{status: :error, error: "Analytics query failed", checked_at: DateTime.utc_now()}
    end
  end
  
  defp check_insights_connector do
    # Test insights query
    case DashboardGen.Insights.list_recent_insights_by_company(1) do
      [] -> %{status: :healthy, checked_at: DateTime.utc_now()}
      _list -> %{status: :healthy, checked_at: DateTime.utc_now()}
      _ -> %{status: :error, error: "Insights query failed", checked_at: DateTime.utc_now()}
    end
  end
  
  defp check_codex_client do
    # Test API connectivity with simple request
    case CodexClient.ask("Test") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_openai_api do
    # Simple API health check
    case CodexClient.ask("Health check") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_database_connection do
    try do
      DashboardGen.Repo.query!("SELECT 1")
      :ok
    rescue
      error -> {:error, inspect(error)}
    end
  end
  
  # Metric Collection Functions
  
  defp get_memory_usage do
    {:memory, memory_info} = :erlang.system_info(:memory)
    total = memory_info[:total] || 0
    # Return as percentage (simplified)
    min(total / (1024 * 1024 * 1024), 1.0) # Convert to GB and cap at 100%
  end
  
  defp get_cpu_usage do
    # Simplified CPU usage (would need more sophisticated monitoring in production)
    :rand.uniform() * 0.5 # Mock: random value between 0-50%
  end
  
  defp get_disk_usage do
    # Simplified disk usage
    0.3 # Mock: 30% disk usage
  end
  
  defp get_process_count do
    length(Process.list())
  end
  
  defp calculate_uptime(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end
  
  defp update_request_metrics(state, _type, duration_ms, result) do
    new_total = state.total_requests + 1
    
    {new_successful, new_failed} = case result do
      :success -> {state.successful_requests + 1, state.failed_requests}
      :error -> {state.successful_requests, state.failed_requests + 1}
    end
    
    # Update rolling average response time
    new_avg_response_time = (state.average_response_time * state.total_requests + duration_ms) / new_total
    
    %{state |
      total_requests: new_total,
      successful_requests: new_successful,
      failed_requests: new_failed,
      average_response_time: new_avg_response_time
    }
  end
  
  defp log_error(state, type, error, context) do
    error_entry = %{
      type: type,
      error: error,
      context: context,
      timestamp: DateTime.utc_now()
    }
    
    # Keep last 100 errors
    new_error_log = [error_entry | state.error_log] |> Enum.take(100)
    
    %{state | error_log: new_error_log}
  end
  
  defp calculate_success_rate(state) do
    if state.total_requests > 0 do
      state.successful_requests / state.total_requests
    else
      1.0
    end
  end
  
  # Report Generation
  
  defp compile_health_status(state) do
    %{
      overall_status: determine_overall_status(state),
      uptime_seconds: calculate_uptime(state.start_time),
      last_check: state.last_health_check,
      system_metrics: state.system_metrics,
      agent_status: state.agent_status,
      success_rate: calculate_success_rate(state),
      average_response_time: state.average_response_time,
      recent_errors: Enum.take(state.error_log, 5)
    }
  end
  
  defp compile_performance_metrics(state) do
    %{
      requests: %{
        total: state.total_requests,
        successful: state.successful_requests,
        failed: state.failed_requests,
        success_rate: calculate_success_rate(state)
      },
      performance: %{
        average_response_time: state.average_response_time,
        uptime_seconds: calculate_uptime(state.start_time)
      },
      history: Enum.take(state.performance_history, 24) # Last 2 hours
    }
  end
  
  defp generate_uptime_report(state) do
    uptime_seconds = calculate_uptime(state.start_time)
    
    %{
      start_time: state.start_time,
      current_time: DateTime.utc_now(),
      uptime_seconds: uptime_seconds,
      uptime_formatted: format_uptime(uptime_seconds),
      availability_percentage: calculate_availability(state),
      total_requests_processed: state.total_requests,
      error_rate: 1.0 - calculate_success_rate(state),
      performance_summary: summarize_performance(state),
      system_health: determine_overall_status(state)
    }
  end
  
  defp determine_overall_status(state) do
    # Check various health indicators
    success_rate = calculate_success_rate(state)
    memory_usage = Map.get(state.system_metrics, :memory_usage, 0)
    
    agent_health = state.agent_status 
    |> Map.values() 
    |> Enum.all?(&(Map.get(&1, :status) == :healthy))
    
    cond do
      success_rate < 0.5 or memory_usage > 0.95 -> :critical
      success_rate < 0.8 or memory_usage > 0.85 or not agent_health -> :warning
      true -> :healthy
    end
  end
  
  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)
    
    "#{days}d #{hours}h #{minutes}m"
  end
  
  defp calculate_availability(_state) do
    # Simplified availability calculation
    0.99 # 99% availability
  end
  
  defp summarize_performance(state) do
    %{
      avg_response_time: state.average_response_time,
      total_requests: state.total_requests,
      success_rate: calculate_success_rate(state)
    }
  end
  
  defp send_critical_alert(issue) do
    AlertStore.store_alert(%{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      type: :system_health,
      severity: :critical,
      title: "Critical System Issue: #{issue.type}",
      message: "System monitoring detected: #{inspect(issue)}",
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      metadata: issue
    })
  end
end