defmodule DashboardGen.DataCollectors.RSSClient do
  @moduledoc """
  RSS feed client for collecting news from Google News, Yahoo Finance, and other RSS sources.
  Free alternative to paid news APIs.
  """

  require Logger
  alias DashboardGen.Sentiment
  import SweetXml

  def collect_google_news(companies) when is_list(companies) do
    results =
      Enum.map(companies, fn company ->
        result =
          case collect_google_news_for_company(company) do
            {:ok, count} ->
              Logger.info("Collected #{count} Google News articles for #{company}")
              count

            {:error, reason} ->
              Logger.error("Failed to collect Google News for #{company}: #{reason}")
              0
          end

        # Be respectful to Google's servers
        Process.sleep(2000)
        result
      end)

    total = Enum.sum(results)
    {:ok, total}
  end

  def collect_yahoo_finance(companies) when is_list(companies) do
    results =
      Enum.map(companies, fn company ->
        result =
          case collect_yahoo_finance_for_company(company) do
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

  @doc """
  Collects business news from Reuters RSS feed and filters by company name.
  """
  @spec collect_reuters_business([String.t()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def collect_reuters_business(companies) when is_list(companies) do
    results =
      Enum.map(companies, fn company ->
        result =
          case collect_reuters_business_for_company(company) do
            {:ok, count} ->
              Logger.info("Collected #{count} Reuters Business articles for #{company}")
              count

            {:error, reason} ->
              Logger.error("Failed to collect Reuters Business for #{company}: #{reason}")
              0
          end

        Process.sleep(2000)
        result
      end)

    {:ok, Enum.sum(results)}
  end

  @doc """
  Collects Reuters Technology news via RSS and filters by company name.
  """
  @spec collect_reuters_technology([String.t()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def collect_reuters_technology(companies) when is_list(companies) do
    results = Enum.map(companies, fn company ->
      result = case collect_reuters_technology_for_company(company) do
        {:ok, count} ->
          Logger.info("Collected #{count} Reuters Technology articles for #{company}")
          count
        {:error, reason} ->
          Logger.error("Failed to collect Reuters Technology for #{company}: #{reason}")
          0
      end
      Process.sleep(2000)
      result
    end)

    {:ok, Enum.sum(results)}
  end

  defp collect_reuters_technology_for_company(company) do
    url = "https://feeds.reuters.com/reuters/technologyNews"

    case fetch_and_parse_rss(url) do
      {:ok, items} ->
        filtered = Enum.filter(items, fn item ->
          String.contains?(item.title || "", company) or
            String.contains?(item.description || "", company)
        end)
        count = process_and_store_rss_items(filtered, company, "reuters_technology")
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Collects Financial Times RSS feed and filters by company name.
  """
  @spec collect_ft_news([String.t()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def collect_ft_news(companies) when is_list(companies) do
    results = Enum.map(companies, fn company ->
      result = case collect_ft_news_for_company(company) do
        {:ok, count} ->
          Logger.info("Collected FT News articles for #{company}: #{count}")
          count
        {:error, reason} ->
          Logger.error("Failed to collect FT News for #{company}: #{reason}")
          0
      end
      Process.sleep(2000)
      result
    end)

    {:ok, Enum.sum(results)}
  end

  defp collect_ft_news_for_company(company) do
    url = "https://www.ft.com/?format=rss"

    case fetch_and_parse_rss(url) do
      {:ok, items} ->
        filtered = Enum.filter(items, fn item ->
          String.contains?(item.title || "", company) or
            String.contains?(item.description || "", company)
        end)
        count = process_and_store_rss_items(filtered, company, "ft_news")
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp collect_reuters_business_for_company(company) do
    url = "https://feeds.reuters.com/reuters/businessNews"

    case fetch_and_parse_rss(url) do
      {:ok, items} ->
        # Filter items mentioning the company in title or description
        filtered =
          Enum.filter(items, fn item ->
            String.contains?(item.title || "", company) or
              String.contains?(item.description || "", company)
          end)

        count = process_and_store_rss_items(filtered, company, "reuters_business")
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
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
    Logger.info("Fetching RSS feed: #{url}")
    headers = [
      {"User-Agent", "Mozilla/5.0 (compatible; DashboardGen/1.0; +http://example.com/bot)"}
    ]

    case HTTPoison.get(url, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} ->
        case parse_rss_body(body) do
          {:ok, items} = ok ->
            Logger.info("RSS feed #{url} returned #{length(items)} items")
            ok

          error ->
            error
        end

      {:ok, %{status_code: status}} ->
        Logger.error("RSS HTTP error #{status} for #{url}")
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        Logger.error("RSS request failed for #{url}: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp parse_rss_body(body) do
    try do
      case SweetXml.parse(body) do
        {:error, reason} ->
          {:error, "XML parse error: #{reason}"}

        parsed_xml ->
          items =
            SweetXml.xpath(parsed_xml, ~x"//item"l,
              title: ~x"./title/text()"s,
              description: ~x"./description/text()"s,
              link: ~x"./link/text()"s,
              pub_date: ~x"./pubDate/text()"s,
              guid: ~x"./guid/text()"s
            )

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

    recent_items =
      Enum.filter(items, fn item ->
        case parse_pub_date(item.pub_date) do
          {:ok, pub_date} -> DateTime.compare(pub_date, cutoff_time) == :gt
          # If we can't parse date, skip it
          :error -> false
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
      # Use major ETF as proxy
      "vanguard" -> "VTI"
      "state street" -> "STT"
      # Use major ETF as proxy
      "fidelity" -> "FDVV"
      "goldman sachs" -> "GS"
      _ -> nil
    end
  end

  defp parse_pub_date(date_string) when is_binary(date_string) do
    # Handle common RSS date formats
    formats = [
      # RFC 2822
      "%a, %d %b %Y %H:%M:%S %z",
      # ISO 8601
      "%Y-%m-%dT%H:%M:%S%z",
      # Simple format
      "%Y-%m-%d %H:%M:%S"
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
    # Remove HTML tags
    |> String.replace(~r/<[^>]*>/, " ")
    # Remove HTML entities
    |> String.replace(~r/&\w+;/, " ")
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
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
