defmodule DashboardGen.DataCollectors.NewsCollector do
  @moduledoc """
  News feed collector for gathering sentiment data from news sources.
  Supports NewsAPI, Google News RSS, and other news aggregators.
  """
  
  use GenServer
  require Logger
  alias DashboardGen.Sentiment
  alias DashboardGen.DataCollectors.{NewsAPIClient, RSSClient}
  
  @collection_interval :timer.hours(1) # Collect every hour
  @default_companies ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"]
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    companies = Keyword.get(opts, :companies, @default_companies)
    enabled_sources = Keyword.get(opts, :sources, [:newsapi, :google_news, :yahoo_finance])
    
    # Schedule initial collection
    Process.send_after(self(), :collect_news, 5000)
    
    state = %{
      companies: companies,
      enabled_sources: enabled_sources,
      last_collection: nil,
      collection_stats: %{total: 0, errors: 0, by_source: %{}}
    }
    
    Logger.info("NewsCollector started with companies: #{inspect(companies)}")
    {:ok, state}
  end
  
  def handle_info(:collect_news, state) do
    Logger.info("Starting news data collection...")
    
    new_stats = collect_from_news_sources(state.companies, state.enabled_sources)
    
    # Schedule next collection
    Process.send_after(self(), :collect_news, @collection_interval)
    
    updated_state = %{state | 
      last_collection: DateTime.utc_now(),
      collection_stats: merge_stats(state.collection_stats, new_stats)
    }
    
    Logger.info("News collection completed. Stats: #{inspect(updated_state.collection_stats)}")
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
  
  ## Public API
  
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def force_collection do
    send(__MODULE__, :collect_news)
  end
  
  ## Private Functions
  
  defp collect_from_news_sources(companies, sources) do
    stats = %{total: 0, errors: 0, by_source: %{}}
    
    Enum.reduce(sources, stats, fn source, acc_stats ->
      case collect_from_news_source(source, companies) do
        {:ok, count} ->
          %{acc_stats | 
            total: acc_stats.total + count,
            by_source: Map.put(acc_stats.by_source, source, count)
          }
        {:error, reason} ->
          Logger.error("News collection failed for #{source}: #{reason}")
          %{acc_stats | 
            errors: acc_stats.errors + 1,
            by_source: Map.put(acc_stats.by_source, source, 0)
          }
      end
    end)
  end
  
  defp collect_from_news_source(:newsapi, companies) do
    NewsAPIClient.collect_news(companies)
  end
  
  defp collect_from_news_source(:google_news, companies) do
    RSSClient.collect_google_news(companies)
  end
  
  defp collect_from_news_source(:yahoo_finance, companies) do
    RSSClient.collect_yahoo_finance(companies)
  end
  
  defp collect_from_news_source(source, _companies) do
    Logger.warning("Unknown news source: #{source}")
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