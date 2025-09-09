defmodule DashboardGen.DataCollectors.NewsAPIClient do
  @moduledoc """
  NewsAPI.org client for collecting financial news and sentiment data.
  Requires API key from newsapi.org (free tier available).
  """

  require Logger
  alias DashboardGen.Sentiment

  @base_url "https://newsapi.org/v2"
  @sources "bloomberg,reuters,financial-times,wall-street-journal,business-insider,cnbc,marketwatch,yahoo-finance"

  def collect_news(companies) when is_list(companies) do
    case get_api_key() do
      nil ->
        Logger.warning("NewsAPI key not configured")
        {:error, "No NewsAPI credentials"}

      api_key ->
        collect_with_api_key(companies, api_key)
    end
  end

  defp collect_with_api_key(companies, api_key) do
    results =
      Enum.map(companies, fn company ->
        result =
          case collect_company_news(company, api_key) do
            {:ok, count} when is_integer(count) ->
              Logger.info("Collected #{count} news articles for #{company}")
              count

            {:ok, other} ->
              Logger.warning(
                "collect_company_news returned {:ok, #{inspect(other)}} instead of integer for #{company}"
              )

              0

            {:error, reason} ->
              Logger.error("Failed to collect news for #{company}: #{reason}")
              0

            other ->
              Logger.error(
                "collect_company_news returned unexpected value: #{inspect(other)} for #{company}"
              )

              0
          end

        # Rate limiting - NewsAPI free tier has limits
        Process.sleep(1000)
        result
      end)

    total = Enum.sum(results)
    {:ok, total}
  end

  defp collect_company_news(company, api_key) do
    query = build_news_query(company)

    case search_everything(query, api_key) do
      {:ok, articles} ->
        processed_count = process_and_store_articles(articles, company)
        {:ok, processed_count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp search_everything(query, api_key) do
    url = "#{@base_url}/everything"

    params = %{
      "q" => query,
      "sources" => @sources,
      "language" => "en",
      "sortBy" => "publishedAt",
      # Max for free tier
      "pageSize" => "50",
      "from" => get_from_date(),
      "apiKey" => api_key
    }

    case HTTPoison.get(url, [], params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"status" => "ok", "articles" => articles}} ->
            {:ok, articles}

          {:ok, %{"status" => "error", "message" => message}} ->
            {:error, "NewsAPI error: #{message}"}

          {:ok, response} ->
            Logger.warning("Unexpected NewsAPI response: #{inspect(response)}")
            {:ok, []}

          {:error, reason} ->
            {:error, "JSON decode error: #{reason}"}
        end

      {:ok, %{status_code: 429}} ->
        Logger.warning("NewsAPI rate limit exceeded")
        {:error, "Rate limit exceeded"}

      {:ok, %{status_code: status, body: body}} ->
        Logger.error("NewsAPI error #{status}: #{body}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp build_news_query(company) do
    # Build comprehensive search query for financial news
    base_terms = [company]

    additional_terms =
      case String.downcase(company) do
        "blackrock" -> ["BlackRock Inc", "BLK stock", "iShares", "Larry Fink"]
        "vanguard" -> ["Vanguard Group", "VTI", "Bogle", "index funds"]
        "state street" -> ["State Street Corp", "STT stock", "SPDR", "custody"]
        "fidelity" -> ["Fidelity Investments", "mutual funds", "Abigail Johnson"]
        "goldman sachs" -> ["Goldman Sachs", "GS stock", "investment banking", "David Solomon"]
        "alliancebernstein" -> ["AllianceBernstein LLC", "AB stock", "Peter Kraus"]
        _ -> []
      end

    # Combine terms with financial context
    all_terms = base_terms ++ additional_terms
    query = Enum.join(all_terms, " OR ")

    # Add financial context terms
    "#{query} AND (investment OR stock OR fund OR finance OR trading OR portfolio)"
  end

  defp process_and_store_articles(articles, company) when is_list(articles) do
    count =
      Enum.reduce(articles, 0, fn article, acc ->
        case process_article(article, company) do
          {:ok, _sentiment_data} -> acc + 1
          {:error, _reason} -> acc
        end
      end)

    count
  end

  defp process_and_store_articles(_, _company) do
    # Handle case where articles is not a list
    0
  end

  defp process_article(article, company) do
    title = article["title"] || ""
    description = article["description"] || ""
    content = "#{title} #{description}" |> String.trim()

    # Skip articles that are too short or likely duplicates
    if String.length(content) < 20 or irrelevant_content?(content) do
      {:error, "Article filtered out"}
    else
      case Sentiment.analyze_sentiment(content, company: company, source: "news") do
        {:ok, analysis} ->
          attrs = %{
            source: "news",
            source_id: generate_article_id(article),
            company: company,
            # Truncate very long content
            content: String.slice(content, 0, 2000),
            content_type: "article",
            author: article["author"],
            url: article["url"],
            platform_data: %{
              source_name: article["source"]["name"],
              published_at: article["publishedAt"],
              url_to_image: article["urlToImage"],
              title: title,
              description: description
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

  defp irrelevant_content?(content) do
    # Filter out common irrelevant patterns
    irrelevant_patterns = [
      ~r/subscribe.*newsletter/i,
      ~r/sign.*up.*free/i,
      ~r/breaking.*news.*alert/i,
      ~r/this.*story.*developing/i,
      ~r/more.*details.*follow/i
    ]

    Enum.any?(irrelevant_patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end

  defp generate_article_id(article) do
    # Create a unique ID from article URL and published date
    url = article["url"] || ""
    published = article["publishedAt"] || ""

    :crypto.hash(:md5, "#{url}#{published}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp get_from_date do
    # Get articles from last 24 hours
    DateTime.utc_now()
    |> DateTime.add(-24, :hour)
    |> DateTime.to_iso8601()
  end

  defp get_api_key do
    key =
      Application.get_env(:dashboard_gen, :newsapi)[:api_key] ||
        System.get_env("NEWSAPI_KEY")

    case key do
      nil -> nil
      "" -> nil
      k when is_binary(k) -> String.trim(k)
    end
  end
end
