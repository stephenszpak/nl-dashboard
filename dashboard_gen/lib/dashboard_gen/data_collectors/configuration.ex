defmodule DashboardGen.DataCollectors.Configuration do
  @moduledoc """
  Configuration management for data collectors.
  Allows dynamic configuration of monitoring targets, sources, and collection parameters.
  """
  
  use GenServer
  require Logger
  
  @default_config %{
    companies: ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"],
    social_sources: [:twitter, :reddit],
    news_sources: [:newsapi, :google_news, :yahoo_finance],
    collection_intervals: %{
      social_media: :timer.minutes(15),
      news: :timer.hours(1)
    },
    api_limits: %{
      twitter: %{requests_per_15min: 300, requests_per_day: 10000},
      reddit: %{requests_per_minute: 60, requests_per_day: 1000},
      newsapi: %{requests_per_day: 1000}
    },
    quality_filters: %{
      min_content_length: 10,
      max_content_length: 5000,
      spam_detection: true,
      duplicate_window_hours: 24
    }
  }
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Load configuration from application environment or database
    config = load_configuration()
    
    Logger.info("Configuration loaded: #{inspect(Map.keys(config))}")
    {:ok, config}
  end
  
  ## Public API
  
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end
  
  def get_config(key) do
    GenServer.call(__MODULE__, {:get_config, key})
  end
  
  def update_config(updates) when is_map(updates) do
    GenServer.call(__MODULE__, {:update_config, updates})
  end
  
  def add_company(company) when is_binary(company) do
    GenServer.call(__MODULE__, {:add_company, company})
  end
  
  def remove_company(company) when is_binary(company) do
    GenServer.call(__MODULE__, {:remove_company, company})
  end
  
  def enable_source(source) when is_atom(source) do
    GenServer.call(__MODULE__, {:enable_source, source})
  end
  
  def disable_source(source) when is_atom(source) do
    GenServer.call(__MODULE__, {:disable_source, source})
  end
  
  def update_api_credentials(service, credentials) when is_map(credentials) do
    GenServer.call(__MODULE__, {:update_api_credentials, service, credentials})
  end
  
  ## GenServer Callbacks
  
  def handle_call(:get_config, _from, config) do
    {:reply, config, config}
  end
  
  def handle_call({:get_config, key}, _from, config) do
    value = Map.get(config, key)
    {:reply, value, config}
  end
  
  def handle_call({:update_config, updates}, _from, config) do
    new_config = Map.merge(config, updates)
    
    # Persist configuration
    case persist_configuration(new_config) do
      :ok -> 
        # Notify collectors of configuration change
        broadcast_config_change(updates)
        {:reply, :ok, new_config}
      {:error, reason} ->
        Logger.error("Failed to persist configuration: #{reason}")
        {:reply, {:error, reason}, config}
    end
  end
  
  def handle_call({:add_company, company}, _from, config) do
    current_companies = Map.get(config, :companies, [])
    
    if company in current_companies do
      {:reply, {:error, :already_exists}, config}
    else
      new_companies = [company | current_companies]
      new_config = Map.put(config, :companies, new_companies)
      
      case persist_configuration(new_config) do
        :ok ->
          broadcast_config_change(%{companies: new_companies})
          {:reply, :ok, new_config}
        {:error, reason} ->
          {:reply, {:error, reason}, config}
      end
    end
  end
  
  def handle_call({:remove_company, company}, _from, config) do
    current_companies = Map.get(config, :companies, [])
    new_companies = List.delete(current_companies, company)
    new_config = Map.put(config, :companies, new_companies)
    
    case persist_configuration(new_config) do
      :ok ->
        broadcast_config_change(%{companies: new_companies})
        {:reply, :ok, new_config}
      {:error, reason} ->
        {:reply, {:error, reason}, config}
    end
  end
  
  def handle_call({:enable_source, source}, _from, config) do
    case determine_source_type(source) do
      {:ok, source_type} ->
        current_sources = Map.get(config, source_type, [])
        
        if source in current_sources do
          {:reply, {:error, :already_enabled}, config}
        else
          new_sources = [source | current_sources]
          new_config = Map.put(config, source_type, new_sources)
          
          case persist_configuration(new_config) do
            :ok ->
              broadcast_config_change(%{source_type => new_sources})
              {:reply, :ok, new_config}
            {:error, reason} ->
              {:reply, {:error, reason}, config}
          end
        end
      {:error, reason} ->
        {:reply, {:error, reason}, config}
    end
  end
  
  def handle_call({:disable_source, source}, _from, config) do
    case determine_source_type(source) do
      {:ok, source_type} ->
        current_sources = Map.get(config, source_type, [])
        new_sources = List.delete(current_sources, source)
        new_config = Map.put(config, source_type, new_sources)
        
        case persist_configuration(new_config) do
          :ok ->
            broadcast_config_change(%{source_type => new_sources})
            {:reply, :ok, new_config}
          {:error, reason} ->
            {:reply, {:error, reason}, config}
        end
      {:error, reason} ->
        {:reply, {:error, reason}, config}
    end
  end
  
  def handle_call({:update_api_credentials, service, credentials}, _from, config) do
    # Store credentials securely (in production, use encrypted storage)
    case store_api_credentials(service, credentials) do
      :ok ->
        Logger.info("API credentials updated for #{service}")
        {:reply, :ok, config}
      {:error, reason} ->
        Logger.error("Failed to update API credentials for #{service}: #{reason}")
        {:reply, {:error, reason}, config}
    end
  end
  
  ## Helper Functions
  
  defp load_configuration do
    # Try to load from database first, fall back to application config, then defaults
    case load_from_database() do
      {:ok, config} -> 
        Logger.info("Configuration loaded from database")
        config
      {:error, _} ->
        Logger.info("Loading configuration from application environment")
        load_from_application_env()
    end
  end
  
  defp load_from_database do
    # In a real implementation, you'd load from a database table
    # For now, we'll simulate this
    {:error, :not_implemented}
  end
  
  defp load_from_application_env do
    app_config = Application.get_env(:dashboard_gen, :data_collectors, %{})
    # Convert keyword list to map if necessary
    app_config_map = if is_list(app_config), do: Enum.into(app_config, %{}), else: app_config
    Map.merge(@default_config, app_config_map)
  end
  
  defp persist_configuration(config) do
    # In production, save to database
    # For now, we'll save to application environment
    try do
      Application.put_env(:dashboard_gen, :data_collectors, config)
      :ok
    rescue
      error -> {:error, inspect(error)}
    end
  end
  
  defp broadcast_config_change(changes) do
    # Notify collectors about configuration changes
    Phoenix.PubSub.broadcast(
      DashboardGen.PubSub,
      "data_collector_config",
      {:config_updated, changes}
    )
  end
  
  defp determine_source_type(source) do
    social_sources = [:twitter, :reddit, :linkedin, :facebook]
    news_sources = [:newsapi, :google_news, :yahoo_finance, :reuters, :bloomberg]
    
    cond do
      source in social_sources -> {:ok, :social_sources}
      source in news_sources -> {:ok, :news_sources}
      true -> {:error, :unknown_source_type}
    end
  end
  
  defp store_api_credentials(service, credentials) do
    # In production, use encrypted storage like Vault, AWS Secrets Manager, etc.
    # For now, store in application environment (NOT secure for production)
    try do
      current_api_config = Application.get_env(:dashboard_gen, service, %{})
      new_api_config = Map.merge(current_api_config, credentials)
      Application.put_env(:dashboard_gen, service, new_api_config)
      :ok
    rescue
      error -> {:error, inspect(error)}
    end
  end
  
  ## Configuration Helpers
  
  def get_company_list do
    get_config(:companies) || []
  end
  
  def get_enabled_social_sources do
    get_config(:social_sources) || []
  end
  
  def get_enabled_news_sources do
    get_config(:news_sources) || []
  end
  
  def get_collection_interval(collector_type) do
    intervals = get_config(:collection_intervals) || %{}
    Map.get(intervals, collector_type, :timer.minutes(15))
  end
  
  def get_api_limits(service) do
    limits = get_config(:api_limits) || %{}
    Map.get(limits, service, %{})
  end
  
  def get_quality_filters do
    get_config(:quality_filters) || %{}
  end
  
  def is_source_enabled?(source) do
    social_sources = get_enabled_social_sources()
    news_sources = get_enabled_news_sources()
    
    source in social_sources or source in news_sources
  end
  
  def validate_configuration(config) when is_map(config) do
    required_keys = [:companies, :social_sources, :news_sources]
    
    missing_keys = Enum.filter(required_keys, fn key ->
      not Map.has_key?(config, key)
    end)
    
    if missing_keys == [] do
      :ok
    else
      {:error, {:missing_keys, missing_keys}}
    end
  end
end