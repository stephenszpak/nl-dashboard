defmodule DashboardGen.DataCollectors.DataCollectorSupervisor do
  @moduledoc """
  Supervisor for all data collection processes.
  Manages social media collectors, news collectors, and ensures they restart on failure.
  """
  
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    # Get configuration from application environment
    config = Application.get_env(:dashboard_gen, :data_collectors, %{})
    # Convert keyword list to map if necessary
    config_map = if is_list(config), do: Enum.into(config, %{}), else: config
    
    companies = Map.get(config_map, :companies, [
      "BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"
    ])
    
    social_sources = Map.get(config_map, :social_sources, [:twitter, :reddit])
    news_sources = Map.get(config_map, :news_sources, [:newsapi, :google_news, :yahoo_finance])
    
    children = [
      # Social Media Collector
      {DashboardGen.DataCollectors.SocialMediaCollector, [
        companies: companies,
        sources: social_sources
      ]},
      
      # News Collector  
      {DashboardGen.DataCollectors.NewsCollector, [
        companies: companies,
        sources: news_sources
      ]},
      
      # Data Processing Pipeline
      {DashboardGen.DataCollectors.DataProcessor, []},
      
      # Rate Limiter for API calls
      {DashboardGen.DataCollectors.RateLimiter, []},
      
      # Collection Status Monitor
      {DashboardGen.DataCollectors.StatusMonitor, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  ## Public API
  
  def get_collection_status do
    social_status = get_child_status(DashboardGen.DataCollectors.SocialMediaCollector)
    news_status = get_child_status(DashboardGen.DataCollectors.NewsCollector)
    processor_status = get_child_status(DashboardGen.DataCollectors.DataProcessor)
    
    %{
      social_media: social_status,
      news: news_status,
      processor: processor_status,
      overall_health: calculate_overall_health([social_status, news_status, processor_status])
    }
  end
  
  def restart_collector(collector_type) do
    child_spec = case collector_type do
      :social_media -> DashboardGen.DataCollectors.SocialMediaCollector
      :news -> DashboardGen.DataCollectors.NewsCollector
      :processor -> DashboardGen.DataCollectors.DataProcessor
      _ -> nil
    end
    
    if child_spec do
      case Supervisor.terminate_child(__MODULE__, child_spec) do
        :ok -> Supervisor.restart_child(__MODULE__, child_spec)
        error -> error
      end
    else
      {:error, :invalid_collector_type}
    end
  end
  
  defp get_child_status(module) do
    case Process.whereis(module) do
      nil -> %{status: :not_running, last_collection: nil}
      pid when is_pid(pid) ->
        try do
          GenServer.call(module, :get_status, 5_000)
        rescue
          _ -> %{status: :error, last_collection: nil}
        catch
          :exit, _ -> %{status: :timeout, last_collection: nil}
        end
    end
  end
  
  defp calculate_overall_health(statuses) do
    running_count = Enum.count(statuses, fn status -> 
      Map.get(status, :status) in [:running, :active]
    end)
    
    total_count = length(statuses)
    
    cond do
      running_count == total_count -> :healthy
      running_count > total_count / 2 -> :degraded
      true -> :unhealthy
    end
  end
end