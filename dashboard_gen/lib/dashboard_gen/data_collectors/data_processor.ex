defmodule DashboardGen.DataCollectors.DataProcessor do
  @moduledoc """
  Data processing pipeline for collected sentiment data.
  Handles deduplication, quality filtering, and batch processing.
  """
  
  use GenServer
  require Logger
  alias DashboardGen.Sentiment
  
  @processing_interval :timer.minutes(5) # Process queue every 5 minutes
  @batch_size 50 # Process in batches of 50
  @duplicate_window_hours 24 # Check for duplicates within 24 hours
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Schedule initial processing
    Process.send_after(self(), :process_queue, 10_000)
    
    state = %{
      processing_queue: [],
      last_processing: nil,
      processing_stats: %{
        processed: 0,
        duplicates_filtered: 0,
        quality_filtered: 0,
        errors: 0
      }
    }
    
    Logger.info("DataProcessor started")
    {:ok, state}
  end
  
  def handle_info(:process_queue, state) do
    Logger.debug("Processing data queue...")
    
    # Get pending data from queue
    {batch, remaining_queue} = take_batch(state.processing_queue, @batch_size)
    
    # Process the batch
    new_stats = process_batch(batch)
    
    # Schedule next processing
    Process.send_after(self(), :process_queue, @processing_interval)
    
    updated_state = %{state |
      processing_queue: remaining_queue,
      last_processing: DateTime.utc_now(),
      processing_stats: merge_processing_stats(state.processing_stats, new_stats)
    }
    
    if length(batch) > 0 do
      Logger.info("Processed #{length(batch)} items. Stats: #{inspect(updated_state.processing_stats)}")
    end
    
    {:noreply, updated_state}
  end
  
  def handle_call({:add_to_queue, data}, _from, state) do
    updated_queue = [data | state.processing_queue]
    {:reply, :ok, %{state | processing_queue: updated_queue}}
  end
  
  def handle_call(:get_status, _from, state) do
    status = %{
      queue_size: length(state.processing_queue),
      last_processing: state.last_processing,
      stats: state.processing_stats,
      next_processing: estimate_next_processing()
    }
    {:reply, status, state}
  end
  
  def handle_call(:force_processing, _from, state) do
    send(self(), :process_queue)
    {:reply, :ok, state}
  end
  
  ## Public API
  
  def add_to_processing_queue(data) when is_map(data) do
    GenServer.call(__MODULE__, {:add_to_queue, data})
  end
  
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def force_processing do
    GenServer.call(__MODULE__, :force_processing)
  end
  
  ## Private Functions
  
  defp take_batch(queue, size) do
    batch = Enum.take(queue, size)
    remaining = Enum.drop(queue, size)
    {batch, remaining}
  end
  
  defp process_batch([]), do: %{processed: 0, duplicates_filtered: 0, quality_filtered: 0, errors: 0}
  
  defp process_batch(batch) do
    Logger.info("Processing batch of #{length(batch)} items")
    
    Enum.reduce(batch, %{processed: 0, duplicates_filtered: 0, quality_filtered: 0, errors: 0}, 
      fn item, acc ->
        case process_single_item(item) do
          {:ok, :processed} -> 
            %{acc | processed: acc.processed + 1}
          {:ok, :duplicate} -> 
            %{acc | duplicates_filtered: acc.duplicates_filtered + 1}
          {:ok, :quality_filtered} -> 
            %{acc | quality_filtered: acc.quality_filtered + 1}
          {:error, _reason} -> 
            %{acc | errors: acc.errors + 1}
        end
      end)
  end
  
  defp process_single_item(data) do
    with {:ok, :unique} <- check_for_duplicates(data),
         {:ok, :quality_passed} <- check_data_quality(data),
         {:ok, enriched_data} <- enrich_data(data),
         {:ok, _sentiment_record} <- store_sentiment_data(enriched_data) do
      {:ok, :processed}
    else
      {:error, :duplicate} -> {:ok, :duplicate}
      {:error, :quality_failed} -> {:ok, :quality_filtered}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_for_duplicates(data) do
    _source = Map.get(data, :source)
    _source_id = Map.get(data, :source_id)
    _content_hash = generate_content_hash(Map.get(data, :content, ""))
    
    _cutoff_time = DateTime.utc_now() |> DateTime.add(-@duplicate_window_hours, :hour)
    
    # Simplified duplicate checking - skip for now
    # In production, implement proper duplicate detection with database queries
    {:ok, :unique}
  end
  
  
  defp check_data_quality(data) do
    content = Map.get(data, :content, "")
    
    cond do
      String.length(content) < 10 ->
        {:error, :quality_failed}
      
      spam_content?(content) ->
        {:error, :quality_failed}
      
      low_quality_source?(data) ->
        {:error, :quality_failed}
      
      true ->
        {:ok, :quality_passed}
    end
  end
  
  defp spam_content?(content) do
    spam_indicators = [
      ~r/buy.*now.*limited.*time/i,
      ~r/click.*here.*make.*money/i,
      ~r/crypto.*profit.*guaranteed/i,
      ~r/free.*money.*easy/i,
      ~r/investment.*opportunity.*urgent/i
    ]
    
    Enum.any?(spam_indicators, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end
  
  defp low_quality_source?(data) do
    # Check for low-quality source indicators
    author = Map.get(data, :author, "")
    url = Map.get(data, :url, "")
    
    low_quality_patterns = [
      ~r/bot|spam|fake/i,           # Likely bot accounts
      ~r/\d{8,}/,                   # Random number usernames
      ~r/bit\.ly|tinyurl|t\.co/,    # Shortened URLs (often spam)
    ]
    
    Enum.any?(low_quality_patterns, fn pattern ->
      Regex.match?(pattern, author) or Regex.match?(pattern, url)
    end)
  end
  
  defp enrich_data(data) do
    # Add processing metadata
    enriched = data
    |> Map.put(:processed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> Map.put(:processing_version, "1.0")
    |> add_geographic_info()
    |> normalize_company_name()
    
    {:ok, enriched}
  end
  
  defp add_geographic_info(data) do
    # Simple geographic inference based on source
    country = case Map.get(data, :source) do
      "twitter" -> infer_country_from_content(Map.get(data, :content, ""))
      "reddit" -> "US" # Reddit is primarily US-based
      "news" -> infer_country_from_url(Map.get(data, :url, ""))
      _ -> nil
    end
    
    if country, do: Map.put(data, :country, country), else: data
  end
  
  defp infer_country_from_content(content) do
    # Simple country inference from currency symbols and terms
    cond do
      Regex.match?(~r/\$|USD|dollar/i, content) -> "US"
      Regex.match?(~r/£|GBP|pound/i, content) -> "UK"
      Regex.match?(~r/€|EUR|euro/i, content) -> "EU"
      true -> "US" # Default
    end
  end
  
  defp infer_country_from_url(url) do
    cond do
      String.contains?(url, ".co.uk") -> "UK"
      String.contains?(url, ".ca") -> "CA"
      String.contains?(url, ".au") -> "AU"
      true -> "US" # Default
    end
  end
  
  defp normalize_company_name(data) do
    company = Map.get(data, :company, "")
    normalized = case String.downcase(company) do
      name when name in ["blackrock", "black rock", "blk"] -> "BlackRock"
      name when name in ["vanguard", "vanguard group"] -> "Vanguard"
      name when name in ["state street", "stt"] -> "State Street"
      name when name in ["fidelity", "fidelity investments"] -> "Fidelity"
      name when name in ["goldman sachs", "goldman", "gs"] -> "Goldman Sachs"
      _ -> company
    end
    
    Map.put(data, :company, normalized)
  end
  
  defp store_sentiment_data(data) do
    Sentiment.create_sentiment_data(data)
  end
  
  defp generate_content_hash(content) do
    :crypto.hash(:md5, content)
    |> Base.encode16(case: :lower)
  end
  
  defp merge_processing_stats(old_stats, new_stats) do
    %{
      processed: old_stats.processed + new_stats.processed,
      duplicates_filtered: old_stats.duplicates_filtered + new_stats.duplicates_filtered,
      quality_filtered: old_stats.quality_filtered + new_stats.quality_filtered,
      errors: old_stats.errors + new_stats.errors
    }
  end
  
  defp estimate_next_processing do
    DateTime.utc_now() |> DateTime.add(@processing_interval, :millisecond)
  end
end