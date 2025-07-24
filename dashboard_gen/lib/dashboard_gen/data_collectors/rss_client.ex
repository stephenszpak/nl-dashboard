defmodule DashboardGen.DataCollectors.RSSClient do
  @moduledoc """
  RSS feed client for collecting news from Google News, Yahoo Finance, and other RSS sources.
  Free alternative to paid news APIs.
  """
  
  require Logger
  alias DashboardGen.Sentiment
  import SweetXml
  
  def collect_google_news(companies) when is_list(companies) do
    results = Enum.map(companies, fn company ->
      result = case collect_google_news_for_company(company) do
        {:ok, count} -> 
          Logger.info("Collected #{count} Google News articles for #{company}")
          count
        {:error, reason} -> 
          Logger.error("Failed to collect Google News for #{company}: #{reason}")
          0
      end
      Process.sleep(2000) # Be respectful to Google's servers
      result
    end)
    
    total = Enum.sum(results)
    {:ok, total}
  end
  
  def collect_yahoo_finance(companies) when is_list(companies) do
    results = Enum.map(companies, fn company ->
      result = case collect_yahoo_finance_for_company(company) do
        {:ok, count} -> 
          Logger.info("Collected #{count} Yahoo Finance articles for #{company}")
          count
        {:error, reason} -> 
          Logger.error("Failed to collect Yahoo Finance for #{company}: #{reason}")
          0
      end
      Process.sleep(2000)
      result
    end)
    
    total = Enum.sum(results)
    {:ok, total}
  end
  
  defp collect_google_news_for_company(company) do
    query = URI.encode(build_google_query(company))
    url = "https://news.google.com/rss/search?q=#{query}&hl=en-US&gl=US&ceid=US:en"
    
    case fetch_and_parse_rss(url) do
      {:ok, items} ->
        processed_count = process_and_store_rss_items(items, company, "google_news")
        {:ok, processed_count}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp collect_yahoo_finance_for_company(company) do
    # Yahoo Finance RSS feeds by stock symbol
    symbol = get_stock_symbol(company)
    
    if symbol do
      url = "https://feeds.finance.yahoo.com/rss/2.0/headline?s=#{symbol}&region=US&lang=en-US"
      
      case fetch_and_parse_rss(url) do
        {:ok, items} ->
          processed_count = process_and_store_rss_items(items, company, "yahoo_finance")
          {:ok, processed_count}
        {:error, reason} ->
          {:error, reason}
      end
    else
      Logger.warning("No stock symbol found for #{company}")
      {:ok, 0}
    end
  end
  
  defp fetch_and_parse_rss(url) do
    headers = [
      {"User-Agent", "Mozilla/5.0 (compatible; DashboardGen/1.0; +http://example.com/bot)"}
    ]
    
    case HTTPoison.get(url, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        parse_rss_body(body)
      {:ok, %{status_code: status}} ->
        {:error, "HTTP error: #{status}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
  
  defp parse_rss_body(body) do
    try do
      case SweetXml.parse(body) do
        {:error, reason} ->
          {:error, "XML parse error: #{reason}"}
        parsed_xml ->
          items = SweetXml.xpath(parsed_xml, ~x"//item"l, [
            title: ~x"./title/text()"s,
            description: ~x"./description/text()"s,
            link: ~x"./link/text()"s,
            pub_date: ~x"./pubDate/text()"s,
            guid: ~x"./guid/text()"s
          ])
          {:ok, items}
      end
    rescue
      error ->
        Logger.error("RSS parsing failed: #{inspect(error)}")
        {:error, "RSS parsing failed"}
    end
  end
  
  defp process_and_store_rss_items(items, company, source) do
    # Filter items from the last 24 hours
    cutoff_time = DateTime.utc_now() |> DateTime.add(-24, :hour)
    
    recent_items = Enum.filter(items, fn item ->
      case parse_pub_date(item.pub_date) do
        {:ok, pub_date} -> DateTime.compare(pub_date, cutoff_time) == :gt
        :error -> false # If we can't parse date, skip it
      end
    end)
    
    Enum.reduce(recent_items, 0, fn item, acc ->
      case process_rss_item(item, company, source) do
        {:ok, _sentiment_data} -> acc + 1
        {:error, _reason} -> acc
      end
    end)
  end
  
  defp process_rss_item(item, company, source) do
    title = item.title |> String.trim()
    description = item.description |> clean_html() |> String.trim()
    content = "#{title} #{description}" |> String.trim()
    
    if String.length(content) < 20 or irrelevant_rss_content?(content) do
      {:error, "Item filtered out"}
    else
      case Sentiment.analyze_sentiment(content, company: company, source: source) do
        {:ok, analysis} ->
          attrs = %{
            source: source,
            source_id: generate_rss_id(item, source),
            company: company,
            content: String.slice(content, 0, 2000),
            content_type: "article",
            author: extract_author_from_description(description),
            url: item.link,
            platform_data: %{
              title: title,
              description: description,
              pub_date: item.pub_date,
              guid: item.guid,
              source: source
            },
            sentiment_score: analysis.sentiment_score,
            sentiment_label: analysis.sentiment_label,
            confidence: analysis.confidence,
            topics: analysis.topics,
            emotions: analysis.emotions,
            analysis_model: analysis.analysis_model,
            language: "en",
            processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
          
          Sentiment.create_sentiment_data(attrs)
        {:error, reason} ->
          {:error, "Sentiment analysis failed: #{reason}"}
      end
    end
  end
  
  defp build_google_query(company) do
    base_query = company
    
    # Add financial context and recent timeframe
    "#{base_query} stock OR investment OR fund OR finance when:7d"
  end
  
  defp get_stock_symbol(company) do
    case String.downcase(company) do
      "blackrock" -> "BLK"
      "vanguard" -> "VTI" # Use major ETF as proxy
      "state street" -> "STT"
      "fidelity" -> "FDVV" # Use major ETF as proxy
      "goldman sachs" -> "GS"
      _ -> nil
    end
  end
  
  defp parse_pub_date(date_string) when is_binary(date_string) do
    # Handle common RSS date formats
    formats = [
      "%a, %d %b %Y %H:%M:%S %z", # RFC 2822
      "%Y-%m-%dT%H:%M:%S%z",      # ISO 8601
      "%Y-%m-%d %H:%M:%S"         # Simple format
    ]
    
    Enum.find_value(formats, :error, fn format ->
      case Timex.parse(date_string, format) do
        {:ok, datetime} -> {:ok, datetime}
        {:error, _} -> nil
      end
    end)
  end
  
  defp parse_pub_date(_), do: :error
  
  defp clean_html(text) when is_binary(text) do
    text
    |> String.replace(~r/<[^>]*>/, " ") # Remove HTML tags
    |> String.replace(~r/&\w+;/, " ")   # Remove HTML entities
    |> String.replace(~r/\s+/, " ")     # Normalize whitespace
    |> String.trim()
  end
  
  defp clean_html(_), do: ""
  
  defp irrelevant_rss_content?(content) do
    irrelevant_patterns = [
      ~r/subscribe.*newsletter/i,
      ~r/read.*full.*story/i,
      ~r/view.*gallery/i,
      ~r/click.*here.*more/i
    ]
    
    Enum.any?(irrelevant_patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end
  
  defp extract_author_from_description(description) do
    # Try to extract author from description patterns
    case Regex.run(~r/by\s+([^,\n]+)/i, description) do
      [_, author] -> String.trim(author)
      _ -> nil
    end
  end
  
  defp generate_rss_id(item, source) do
    # Generate unique ID from guid, link, or title
    identifier = item.guid || item.link || item.title || ""
    
    :crypto.hash(:md5, "#{source}:#{identifier}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
end