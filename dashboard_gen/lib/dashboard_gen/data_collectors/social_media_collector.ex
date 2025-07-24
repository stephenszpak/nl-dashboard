defmodule DashboardGen.DataCollectors.SocialMediaCollector do
  @moduledoc """
  Collects real-time data from social media platforms for sentiment analysis.
  Supports Twitter/X API v2, Reddit API, and other social platforms.
  """
  
  use GenServer
  require Logger
  alias DashboardGen.Sentiment
  alias DashboardGen.DataCollectors.{TwitterClient, RedditClient, LinkedInClient}
  
  @collection_interval :timer.minutes(15) # Collect every 15 minutes
  @default_companies ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    companies = Keyword.get(opts, :companies, @default_companies)
    enabled_sources = Keyword.get(opts, :sources, [:twitter, :reddit])
    
    # Schedule initial collection
    Process.send_after(self(), :collect_data, 1000)
    
    state = %{
      companies: companies,
      enabled_sources: enabled_sources,
      last_collection: nil,
      collection_stats: %{total: 0, errors: 0, by_source: %{}}
    }
    
    Logger.info("SocialMediaCollector started with companies: #{inspect(companies)}")
    {:ok, state}
  end
  
  def handle_info(:collect_data, state) do
    Logger.info("Starting social media data collection...")
    
    # Collect from all enabled sources
    new_stats = collect_from_sources(state.companies, state.enabled_sources)
    
    # Schedule next collection
    Process.send_after(self(), :collect_data, @collection_interval)
    
    updated_state = %{state | 
      last_collection: DateTime.utc_now(),
      collection_stats: merge_stats(state.collection_stats, new_stats)
    }
    
    Logger.info("Collection completed. Stats: #{inspect(updated_state.collection_stats)}")
    {:noreply, updated_state}
  end
  
  def handle_call(:get_status, _from, state) do
    status = %{
      companies: state.companies,
      enabled_sources: state.enabled_sources,
      last_collection: state.last_collection,
      stats: state.collection_stats,
      next_collection: estimate_next_collection()
    }
    {:reply, status, state}
  end
  
  def handle_call({:add_company, company}, _from, state) do
    new_companies = [company | state.companies] |> Enum.uniq()
    new_state = %{state | companies: new_companies}
    {:reply, :ok, new_state}
  end
  
  def handle_call({:remove_company, company}, _from, state) do
    new_companies = List.delete(state.companies, company)
    new_state = %{state | companies: new_companies}
    {:reply, :ok, new_state}
  end
  
  ## Public API
  
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def add_company(company) do
    GenServer.call(__MODULE__, {:add_company, company})
  end
  
  def remove_company(company) do
    GenServer.call(__MODULE__, {:remove_company, company})
  end
  
  def force_collection do
    send(__MODULE__, :collect_data)
  end
  
  ## Private Functions
  
  defp collect_from_sources(companies, sources) do
    stats = %{total: 0, errors: 0, by_source: %{}}
    
    Enum.reduce(sources, stats, fn source, acc_stats ->
      case collect_from_source(source, companies) do
        {:ok, count} ->
          %{acc_stats | 
            total: acc_stats.total + count,
            by_source: Map.put(acc_stats.by_source, source, count)
          }
        {:error, reason} ->
          Logger.error("Collection failed for #{source}: #{reason}")
          %{acc_stats | 
            errors: acc_stats.errors + 1,
            by_source: Map.put(acc_stats.by_source, source, 0)
          }
      end
    end)
  end
  
  defp collect_from_source(:twitter, companies) do
    TwitterClient.collect_mentions(companies)
  end
  
  defp collect_from_source(:reddit, companies) do
    RedditClient.collect_mentions(companies)
  end
  
  defp collect_from_source(:linkedin, companies) do
    LinkedInClient.collect_mentions(companies)
  end
  
  defp collect_from_source(source, _companies) do
    Logger.warning("Unknown source: #{source}")
    {:error, "Unknown source"}
  end
  
  defp merge_stats(old_stats, new_stats) do
    %{
      total: old_stats.total + new_stats.total,
      errors: old_stats.errors + new_stats.errors,
      by_source: Map.merge(old_stats.by_source || %{}, new_stats.by_source || %{}, fn _k, v1, v2 -> v1 + v2 end)
    }
  end
  
  defp estimate_next_collection do
    DateTime.utc_now() |> DateTime.add(@collection_interval, :millisecond)
  end
end