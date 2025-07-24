defmodule DashboardGen.DataCollectors.StatusMonitor do
  @moduledoc """
  Monitors the health and status of all data collection processes.
  Provides real-time status information and alerts for issues.
  """
  
  use GenServer
  require Logger
  
  @status_check_interval :timer.minutes(2)
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Schedule initial status check
    Process.send_after(self(), :check_status, 5_000)
    
    state = %{
      last_check: nil,
      status_history: [],
      alerts: [],
      collectors_status: %{}
    }
    
    Logger.info("StatusMonitor started")
    {:ok, state}
  end
  
  def handle_info(:check_status, state) do
    Logger.debug("Checking collector status...")
    
    # Check status of all collectors
    new_status = check_all_collectors()
    
    # Analyze status and generate alerts if needed
    new_alerts = analyze_status_and_generate_alerts(new_status, state.collectors_status)
    
    # Update status history (keep last 100 entries)
    new_history = [%{timestamp: DateTime.utc_now(), status: new_status} | state.status_history]
                  |> Enum.take(100)
    
    # Schedule next check
    Process.send_after(self(), :check_status, @status_check_interval)
    
    updated_state = %{state |
      last_check: DateTime.utc_now(),
      status_history: new_history,
      alerts: new_alerts,
      collectors_status: new_status
    }
    
    # Broadcast status update
    broadcast_status_update(updated_state)
    
    {:noreply, updated_state}
  end
  
  def handle_call(:get_status, _from, state) do
    status_summary = %{
      overall_health: calculate_overall_health(state.collectors_status),
      last_check: state.last_check,
      collectors: state.collectors_status,
      active_alerts: length(state.alerts),
      alerts: Enum.take(state.alerts, 10) # Return last 10 alerts
    }
    
    {:reply, status_summary, state}
  end
  
  def handle_call(:get_detailed_status, _from, state) do
    detailed_status = %{
      collectors: state.collectors_status,
      alerts: state.alerts,
      history: Enum.take(state.status_history, 20), # Last 20 status checks
      rate_limits: get_rate_limit_status(),
      system_info: get_system_info()
    }
    
    {:reply, detailed_status, state}
  end
  
  def handle_call(:clear_alerts, _from, state) do
    new_state = %{state | alerts: []}
    {:reply, :ok, new_state}
  end
  
  ## Public API
  
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def get_detailed_status do
    GenServer.call(__MODULE__, :get_detailed_status)
  end
  
  def clear_alerts do
    GenServer.call(__MODULE__, :clear_alerts)
  end
  
  def force_status_check do
    send(__MODULE__, :check_status)
  end
  
  ## Private Functions
  
  defp check_all_collectors do
    collectors = [
      {:social_media, DashboardGen.DataCollectors.SocialMediaCollector},
      {:news, DashboardGen.DataCollectors.NewsCollector},
      {:processor, DashboardGen.DataCollectors.DataProcessor}
    ]
    
    Enum.reduce(collectors, %{}, fn {type, module}, acc ->
      status = check_collector_status(module)
      Map.put(acc, type, status)
    end)
  end
  
  defp check_collector_status(module) do
    case Process.whereis(module) do
      nil ->
        %{
          status: :not_running,
          process: :dead,
          last_collection: nil,
          stats: %{},
          error: "Process not found"
        }
      
      pid when is_pid(pid) ->
        try do
          case GenServer.call(module, :get_status, 10_000) do
            status when is_map(status) ->
              %{
                status: :running,
                process: :alive,
                pid: inspect(pid),
                last_collection: Map.get(status, :last_collection),
                stats: Map.get(status, :stats, %{}),
                next_collection: Map.get(status, :next_collection),
                queue_size: Map.get(status, :queue_size, 0)
              }
            _ ->
              %{
                status: :unknown,
                process: :alive,
                error: "Invalid status response"
              }
          end
        rescue
          error ->
            %{
              status: :error,
              process: :alive,
              error: "Status check failed: #{inspect(error)}"
            }
        catch
          :exit, reason ->
            %{
              status: :timeout,
              process: :alive,
              error: "Status check timeout: #{inspect(reason)}"
            }
        end
    end
  end
  
  defp analyze_status_and_generate_alerts(new_status, old_status) do
    alerts = []
    
    # Check for collectors that stopped working
    alerts = check_for_dead_collectors(new_status, alerts)
    
    # Check for collectors with errors
    alerts = check_for_error_conditions(new_status, alerts)
    
    # Check for stale data (no recent collections)
    alerts = check_for_stale_collections(new_status, alerts)
    
    # Check for performance issues
    alerts = check_for_performance_issues(new_status, old_status, alerts)
    
    alerts
  end
  
  defp check_for_dead_collectors(status, alerts) do
    dead_collectors = Enum.filter(status, fn {_type, collector_status} ->
      Map.get(collector_status, :status) == :not_running
    end)
    
    Enum.reduce(dead_collectors, alerts, fn {type, _status}, acc ->
      alert = %{
        type: :collector_down,
        severity: :critical,
        collector: type,
        message: "#{type} collector is not running",
        timestamp: DateTime.utc_now()
      }
      [alert | acc]
    end)
  end
  
  defp check_for_error_conditions(status, alerts) do
    error_collectors = Enum.filter(status, fn {_type, collector_status} ->
      Map.get(collector_status, :status) in [:error, :timeout]
    end)
    
    Enum.reduce(error_collectors, alerts, fn {type, collector_status}, acc ->
      alert = %{
        type: :collector_error,
        severity: :high,
        collector: type,
        message: "#{type} collector error: #{Map.get(collector_status, :error, 'Unknown error')}",
        timestamp: DateTime.utc_now()
      }
      [alert | acc]
    end)
  end
  
  defp check_for_stale_collections(status, alerts) do
    stale_threshold = DateTime.utc_now() |> DateTime.add(-2, :hour)
    
    stale_collectors = Enum.filter(status, fn {type, collector_status} ->
      case Map.get(collector_status, :last_collection) do
        nil -> true # Never collected
        last_collection when is_binary(last_collection) ->
          case DateTime.from_iso8601(last_collection) do
            {:ok, datetime, _} -> DateTime.compare(datetime, stale_threshold) == :lt
            _ -> true
          end
        %DateTime{} = datetime ->
          DateTime.compare(datetime, stale_threshold) == :lt
        _ -> true
      end
    end)
    
    Enum.reduce(stale_collectors, alerts, fn {type, _status}, acc ->
      alert = %{
        type: :stale_data,
        severity: :medium,
        collector: type,
        message: "#{type} collector has not collected data in over 2 hours",
        timestamp: DateTime.utc_now()
      }
      [alert | acc]
    end)
  end
  
  defp check_for_performance_issues(new_status, old_status, alerts) do
    # Check for growing queue sizes (data processor)
    processor_status = Map.get(new_status, :processor, %{})
    queue_size = Map.get(processor_status, :queue_size, 0)
    
    if queue_size > 1000 do
      alert = %{
        type: :performance_issue,
        severity: :medium,
        collector: :processor,
        message: "Data processor queue size is high: #{queue_size} items",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp calculate_overall_health(collectors_status) do
    total_collectors = map_size(collectors_status)
    
    if total_collectors == 0 do
      :unknown
    else
      healthy_collectors = Enum.count(collectors_status, fn {_type, status} ->
        Map.get(status, :status) == :running
      end)
      
      health_ratio = healthy_collectors / total_collectors
      
      cond do
        health_ratio >= 1.0 -> :healthy
        health_ratio >= 0.5 -> :degraded
        true -> :critical
      end
    end
  end
  
  defp get_rate_limit_status do
    case Process.whereis(DashboardGen.DataCollectors.RateLimiter) do
      nil -> %{status: :not_available}
      _pid ->
        try do
          DashboardGen.DataCollectors.RateLimiter.get_all_status()
        rescue
          _ -> %{status: :error}
        catch
          :exit, _ -> %{status: :timeout}
        end
    end
  end
  
  defp get_system_info do
    %{
      erlang_version: :erlang.system_info(:otp_release),
      elixir_version: System.version(),
      memory_usage: :erlang.memory(),
      process_count: :erlang.system_info(:process_count),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    }
  end
  
  defp broadcast_status_update(state) do
    Phoenix.PubSub.broadcast(
      DashboardGen.PubSub,
      "data_collector_status",
      {:status_update, %{
        overall_health: calculate_overall_health(state.collectors_status),
        collectors: state.collectors_status,
        alerts_count: length(state.alerts),
        last_check: state.last_check
      }}
    )
  end
end