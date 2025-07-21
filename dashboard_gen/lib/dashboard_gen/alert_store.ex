defmodule DashboardGen.AlertStore do
  @moduledoc """
  In-memory storage for agent alerts and notifications.
  
  Provides fast access to recent alerts for dashboard display
  and real-time updates.
  """
  
  use GenServer
  require Logger
  
  @max_alerts 100
  @cleanup_interval :timer.hours(1)
  @alert_retention_hours 24
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{alerts: [], alert_count: 0}}
  end
  
  @doc """
  Store a new alert
  """
  def store_alert(alert) do
    GenServer.cast(__MODULE__, {:store_alert, alert})
  end
  
  @doc """
  Get recent alerts
  """
  def get_recent_alerts(limit \\ 20) do
    GenServer.call(__MODULE__, {:get_recent_alerts, limit})
  end
  
  @doc """
  Get alerts by type
  """
  def get_alerts_by_type(type, limit \\ 10) do
    GenServer.call(__MODULE__, {:get_alerts_by_type, type, limit})
  end
  
  @doc """
  Get unacknowledged alerts
  """
  def get_unacknowledged_alerts do
    GenServer.call(__MODULE__, :get_unacknowledged_alerts)
  end
  
  @doc """
  Acknowledge an alert
  """
  def acknowledge_alert(alert_id) do
    GenServer.cast(__MODULE__, {:acknowledge_alert, alert_id})
  end
  
  @doc """
  Get alert statistics
  """
  def get_alert_stats do
    GenServer.call(__MODULE__, :get_alert_stats)
  end
  
  # GenServer callbacks
  
  def handle_cast({:store_alert, alert}, state) do
    new_alerts = [alert | state.alerts]
    |> Enum.take(@max_alerts) # Keep only most recent alerts
    
    new_state = %{state | 
      alerts: new_alerts, 
      alert_count: state.alert_count + 1
    }
    
    Logger.info("Stored alert: #{alert.type} - #{alert.title}")
    
    # Broadcast to subscribers (LiveView, etc.)
    broadcast_alert(alert)
    
    {:noreply, new_state}
  end
  
  def handle_cast({:acknowledge_alert, alert_id}, state) do
    new_alerts = Enum.map(state.alerts, fn alert ->
      if alert.id == alert_id do
        %{alert | acknowledged: true, acknowledged_at: DateTime.utc_now()}
      else
        alert
      end
    end)
    
    {:noreply, %{state | alerts: new_alerts}}
  end
  
  def handle_call({:get_recent_alerts, limit}, _from, state) do
    alerts = Enum.take(state.alerts, limit)
    {:reply, alerts, state}
  end
  
  def handle_call({:get_alerts_by_type, type, limit}, _from, state) do
    alerts = state.alerts
    |> Enum.filter(&(&1.type == type))
    |> Enum.take(limit)
    
    {:reply, alerts, state}
  end
  
  def handle_call(:get_unacknowledged_alerts, _from, state) do
    alerts = Enum.filter(state.alerts, &(!&1.acknowledged))
    {:reply, alerts, state}
  end
  
  def handle_call(:get_alert_stats, _from, state) do
    stats = calculate_alert_stats(state.alerts, state.alert_count)
    {:reply, stats, state}
  end
  
  def handle_info(:cleanup_old_alerts, state) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@alert_retention_hours * 3600, :second)
    
    new_alerts = Enum.filter(state.alerts, fn alert ->
      DateTime.compare(alert.timestamp, cutoff_time) == :gt
    end)
    
    removed_count = length(state.alerts) - length(new_alerts)
    if removed_count > 0 do
      Logger.info("Cleaned up #{removed_count} old alerts")
    end
    
    schedule_cleanup()
    {:noreply, %{state | alerts: new_alerts}}
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_alerts, @cleanup_interval)
  end
  
  defp broadcast_alert(alert) do
    # Broadcast to Phoenix PubSub for real-time updates
    # Phoenix.PubSub.broadcast(DashboardGen.PubSub, "alerts", {:new_alert, alert})
    
    # For now, just log
    Logger.info("Broadcasting alert: #{alert.id}")
  end
  
  defp calculate_alert_stats(alerts, total_count) do
    now = DateTime.utc_now()
    last_hour = DateTime.add(now, -3600, :second)
    last_24h = DateTime.add(now, -86400, :second)
    
    alerts_last_hour = Enum.count(alerts, &(DateTime.compare(&1.timestamp, last_hour) == :gt))
    alerts_last_24h = Enum.count(alerts, &(DateTime.compare(&1.timestamp, last_24h) == :gt))
    
    unacknowledged = Enum.count(alerts, &(!&1.acknowledged))
    
    by_type = Enum.group_by(alerts, & &1.type)
    |> Enum.map(fn {type, type_alerts} -> {type, length(type_alerts)} end)
    |> Enum.into(%{})
    
    by_severity = Enum.group_by(alerts, & &1.severity)
    |> Enum.map(fn {severity, severity_alerts} -> {severity, length(severity_alerts)} end)
    |> Enum.into(%{})
    
    %{
      total_alerts: total_count,
      active_alerts: length(alerts),
      alerts_last_hour: alerts_last_hour,
      alerts_last_24h: alerts_last_24h,
      unacknowledged: unacknowledged,
      by_type: by_type,
      by_severity: by_severity,
      last_alert: List.first(alerts),
      generated_at: now
    }
  end
end