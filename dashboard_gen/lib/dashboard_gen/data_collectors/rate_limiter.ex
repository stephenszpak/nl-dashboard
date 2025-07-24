defmodule DashboardGen.DataCollectors.RateLimiter do
  @moduledoc """
  Rate limiter for API calls to prevent exceeding API quotas.
  Implements token bucket algorithm with per-service rate limiting.
  """
  
  use GenServer
  require Logger
  
  @default_limits %{
    twitter: %{
      requests_per_15min: 300,
      requests_per_hour: 900,
      requests_per_day: 10000
    },
    reddit: %{
      requests_per_minute: 60,
      requests_per_hour: 3600,
      requests_per_day: 50000
    },
    newsapi: %{
      requests_per_hour: 1000,
      requests_per_day: 1000
    },
    google_news: %{
      requests_per_minute: 30,
      requests_per_hour: 1000
    }
  }
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Initialize rate limit counters for each service
    state = %{
      limits: load_rate_limits(),
      counters: initialize_counters(),
      last_reset: %{}
    }
    
    # Schedule periodic counter resets
    schedule_reset_timers()
    
    Logger.info("RateLimiter started with services: #{inspect(Map.keys(state.limits))}")
    {:ok, state}
  end
  
  def handle_call({:check_rate_limit, service}, _from, state) do
    case check_service_rate_limit(service, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:get_rate_limit_status, service}, _from, state) do
    status = get_service_status(service, state)
    {:reply, status, state}
  end
  
  def handle_call(:get_all_status, _from, state) do
    all_status = get_all_services_status(state)
    {:reply, all_status, state}
  end
  
  def handle_info({:reset_counters, period, service}, state) do
    new_state = reset_service_counters(state, service, period)
    
    # Schedule next reset for this period
    schedule_service_reset(service, period)
    
    {:noreply, new_state}
  end
  
  def handle_info({:reset_all_counters, period}, state) do
    new_state = reset_all_counters(state, period)
    
    # Schedule next reset
    schedule_period_reset(period)
    
    {:noreply, new_state}
  end
  
  ## Public API
  
  def check_rate_limit(service) when is_atom(service) do
    GenServer.call(__MODULE__, {:check_rate_limit, service})
  end
  
  def get_rate_limit_status(service) when is_atom(service) do
    GenServer.call(__MODULE__, {:get_rate_limit_status, service})
  end
  
  def get_all_status do
    GenServer.call(__MODULE__, :get_all_status)
  end
  
  def wait_for_rate_limit(service) when is_atom(service) do
    case check_rate_limit(service) do
      :ok -> :ok
      {:error, {:rate_limited, wait_time}} ->
        Logger.info("Rate limited for #{service}, waiting #{wait_time}ms")
        Process.sleep(wait_time)
        :ok
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  ## Private Functions
  
  defp load_rate_limits do
    # Load from configuration, fall back to defaults
    config_limits = Application.get_env(:dashboard_gen, :rate_limits, %{})
    Map.merge(@default_limits, config_limits)
  end
  
  defp initialize_counters do
    # Initialize counters for all services and time periods
    %{
      "15min" => %{},
      minute: %{},
      hour: %{},
      day: %{}
    }
  end
  
  defp check_service_rate_limit(service, state) do
    limits = Map.get(state.limits, service, %{})
    counters = state.counters
    
    # Check all applicable limits for the service
    limit_checks = [
      {:minute, Map.get(limits, :requests_per_minute)},
      {:hour, Map.get(limits, :requests_per_hour)},
      {:day, Map.get(limits, :requests_per_day)},
      {"15min", Map.get(limits, :requests_per_15min)}
    ]
    
    case check_limits(service, limit_checks, counters) do
      :ok ->
        # Increment counters
        new_counters = increment_service_counters(counters, service)
        new_state = %{state | counters: new_counters}
        {:ok, new_state}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp check_limits(_service, [], _counters), do: :ok
  
  defp check_limits(service, [{period, nil} | rest], counters) do
    # Skip periods without limits
    check_limits(service, rest, counters)
  end
  
  defp check_limits(service, [{period, limit} | rest], counters) do
    current_count = get_in(counters, [period, service]) || 0
    
    if current_count >= limit do
      wait_time = calculate_wait_time(period)
      {:error, {:rate_limited, wait_time}}
    else
      check_limits(service, rest, counters)
    end
  end
  
  defp increment_service_counters(counters, service) do
    periods = [:minute, :hour, :day, "15min"]
    
    Enum.reduce(periods, counters, fn period, acc_counters ->
      current_count = get_in(acc_counters, [period, service]) || 0
      put_in(acc_counters, [period, service], current_count + 1)
    end)
  end
  
  defp get_service_status(service, state) do
    limits = Map.get(state.limits, service, %{})
    counters = state.counters
    
    %{
      service: service,
      limits: limits,
      current_usage: %{
        "15min" => get_in(counters, ["15min", service]) || 0,
        minute: get_in(counters, [:minute, service]) || 0,
        hour: get_in(counters, [:hour, service]) || 0,
        day: get_in(counters, [:day, service]) || 0
      },
      remaining: calculate_remaining_requests(service, limits, counters),
      reset_times: calculate_reset_times()
    }
  end
  
  defp get_all_services_status(state) do
    services = Map.keys(state.limits)
    
    Enum.map(services, fn service ->
      get_service_status(service, state)
    end)
  end
  
  defp reset_service_counters(state, service, period) do
    new_counters = put_in(state.counters, [period, service], 0)
    new_last_reset = Map.put(state.last_reset, {service, period}, DateTime.utc_now())
    
    Logger.debug("Reset #{period} counter for #{service}")
    
    %{state | 
      counters: new_counters,
      last_reset: new_last_reset
    }
  end
  
  defp reset_all_counters(state, period) do
    services = Map.keys(state.limits)
    
    new_counters = Enum.reduce(services, state.counters, fn service, acc ->
      put_in(acc, [period, service], 0)
    end)
    
    new_last_reset = Enum.reduce(services, state.last_reset, fn service, acc ->
      Map.put(acc, {service, period}, DateTime.utc_now())
    end)
    
    Logger.debug("Reset all #{period} counters")
    
    %{state |
      counters: new_counters, 
      last_reset: new_last_reset
    }
  end
  
  defp calculate_remaining_requests(service, limits, counters) do
    %{
      "15min" => calculate_remaining(limits, :requests_per_15min, counters, "15min", service),
      minute: calculate_remaining(limits, :requests_per_minute, counters, :minute, service),
      hour: calculate_remaining(limits, :requests_per_hour, counters, :hour, service),
      day: calculate_remaining(limits, :requests_per_day, counters, :day, service)
    }
  end
  
  defp calculate_remaining(limits, limit_key, counters, period, service) do
    limit = Map.get(limits, limit_key)
    current = get_in(counters, [period, service]) || 0
    
    if limit, do: max(0, limit - current), else: nil
  end
  
  defp calculate_wait_time(period) do
    case period do
      :minute -> :timer.minutes(1)
      "15min" -> :timer.minutes(15)
      :hour -> :timer.hours(1)
      :day -> :timer.hours(24)
    end
  end
  
  defp calculate_reset_times do
    now = DateTime.utc_now()
    
    %{
      "15min" => DateTime.add(now, 15 * 60, :second) |> DateTime.truncate(:minute),
      minute: DateTime.add(now, 60, :second) |> DateTime.truncate(:second),
      hour: DateTime.add(now, 3600, :second) |> DateTime.truncate(:minute),
      day: DateTime.add(now, 24 * 3600, :second) |> DateTime.truncate(:hour)
    }
  end
  
  defp schedule_reset_timers do
    # Schedule resets for different periods
    schedule_period_reset(:minute)
    schedule_period_reset("15min")
    schedule_period_reset(:hour)
    schedule_period_reset(:day)
  end
  
  defp schedule_period_reset(period) do
    reset_interval = case period do
      :minute -> :timer.minutes(1)
      "15min" -> :timer.minutes(15)
      :hour -> :timer.hours(1)
      :day -> :timer.hours(24)
    end
    
    Process.send_after(self(), {:reset_all_counters, period}, reset_interval)
  end
  
  defp schedule_service_reset(service, period) do
    reset_interval = calculate_wait_time(period)
    Process.send_after(self(), {:reset_counters, period, service}, reset_interval)
  end
end