defmodule DashboardGen.DataCollectors.TwitterClient do
  @moduledoc """
  Twitter/X API v2 client for collecting mentions and sentiment data.
  Handles authentication, rate limiting, and data processing.
  """
  
  require Logger
  alias DashboardGen.Sentiment
  alias DashboardGen.DataCollectors.DataProcessor
  
  @base_url "https://api.twitter.com/2"
  @rate_limit_window 900_000 # 15 minutes in milliseconds
  @max_requests_per_window 300
  
  def collect_mentions(companies) when is_list(companies) do
    case get_bearer_token() do
      nil -> 
        Logger.warning("Twitter Bearer Token not configured")
        {:error, "No Twitter credentials"}
      token ->
        collect_with_token(companies, token)
    end
  end
  
  defp collect_with_token(companies, token) do
    total_collected = 0
    
    results = Enum.map(companies, fn company ->
      case collect_company_mentions(company, token) do
        {:ok, count} -> 
          Logger.info("Collected #{count} Twitter mentions for #{company}")
          count
        {:error, reason} -> 
          Logger.error("Failed to collect Twitter mentions for #{company}: #{reason}")
          0
      end
      # Add delay between company searches to respect rate limits
      Process.sleep(1000)
    end)
    
    total = Enum.sum(results)
    {:ok, total}
  end
  
  defp collect_company_mentions(company, token) do
    query = build_search_query(company)
    
    case search_tweets(query, token) do
      {:ok, tweets} ->
        processed_count = process_and_store_tweets(tweets, company)
        {:ok, processed_count}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp search_tweets(query, token) do
    url = "#{@base_url}/tweets/search/recent"
    
    params = %{
      "query" => query,
      "max_results" => "100",
      "tweet.fields" => "created_at,author_id,public_metrics,context_annotations,lang",
      "user.fields" => "username,name,verified",
      "expansions" => "author_id"
    }
    
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
    
    case HTTPoison.get(url, headers, params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => tweets} = response} ->
            # Include users data for enrichment
            users = get_in(response, ["includes", "users"]) || []
            enriched_tweets = enrich_tweets_with_users(tweets, users)
            {:ok, enriched_tweets}
          {:ok, %{"meta" => %{"result_count" => 0}}} ->
            {:ok, []}
          {:ok, response} ->
            Logger.warning("Unexpected Twitter API response: #{inspect(response)}")
            {:ok, []}
          {:error, reason} ->
            {:error, "JSON decode error: #{reason}"}
        end
      {:ok, %{status_code: 429}} ->
        Logger.warning("Twitter API rate limit exceeded")
        {:error, "Rate limit exceeded"}
      {:ok, %{status_code: status, body: body}} ->
        Logger.error("Twitter API error #{status}: #{body}")
        {:error, "API error: #{status}"}
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Request failed"}
    end
  end
  
  defp build_search_query(company) do
    # Build a comprehensive search query for the company
    base_terms = [company]
    
    # Add common variations and stock tickers
    additional_terms = case String.downcase(company) do
      "blackrock" -> ["BLK", "$BLK", "@BlackRock"]
      "vanguard" -> ["VTI", "$VTI", "@Vanguard_Group"]
      "state street" -> ["STT", "$STT", "@StateStreet"]
      "fidelity" -> ["@Fidelity", "FidelityInvest"]
      "goldman sachs" -> ["GS", "$GS", "@GoldmanSachs", "Goldman"]
      _ -> []
    end
    
    all_terms = base_terms ++ additional_terms
    query = Enum.join(all_terms, " OR ")
    
    # Add filters to focus on relevant content
    filters = [
      "-is:retweet", # Exclude retweets
      "lang:en",     # English only
      "-is:reply"    # Exclude replies for cleaner data
    ]
    
    "#{query} #{Enum.join(filters, " ")}"
  end
  
  defp enrich_tweets_with_users(tweets, users) do
    users_by_id = Map.new(users, fn user -> {user["id"], user} end)
    
    Enum.map(tweets, fn tweet ->
      user = Map.get(users_by_id, tweet["author_id"], %{})
      Map.put(tweet, "author", user)
    end)
  end
  
  defp process_and_store_tweets(tweets, company) do
    processed_count = 0
    
    Enum.reduce(tweets, processed_count, fn tweet, acc ->
      case process_tweet(tweet, company) do
        {:ok, _sentiment_data} -> acc + 1
        {:error, reason} -> 
          Logger.debug("Failed to process tweet: #{reason}")
          acc
      end
    end)
  end
  
  defp process_tweet(tweet, company) do
    # Extract relevant data from tweet
    content = tweet["text"]
    author_info = tweet["author"] || %{}
    
    # Skip tweets that are too short or likely spam
    if String.length(content) < 10 or spam_indicators?(content) do
      {:error, "Tweet filtered out"}
    else
      # Analyze sentiment using our AI system
      case Sentiment.analyze_sentiment(content, company: company, source: "twitter") do
        {:ok, analysis} ->
          # Create sentiment data record
          attrs = %{
            source: "twitter",
            source_id: tweet["id"],
            company: company,
            content: content,
            content_type: "post",
            author: author_info["username"],
            url: build_tweet_url(author_info["username"], tweet["id"]),
            platform_data: %{
              tweet_id: tweet["id"],
              author_id: tweet["author_id"],
              created_at: tweet["created_at"],
              public_metrics: tweet["public_metrics"],
              verified: author_info["verified"] || false,
              lang: tweet["lang"]
            },
            sentiment_score: analysis.sentiment_score,
            sentiment_label: analysis.sentiment_label,
            confidence: analysis.confidence,
            topics: analysis.topics,
            emotions: analysis.emotions,
            analysis_model: analysis.analysis_model,
            language: tweet["lang"] || "en"
          }
          
          Sentiment.create_sentiment_data(attrs)
        {:error, reason} ->
          {:error, "Sentiment analysis failed: #{reason}"}
      end
    end
  end
  
  defp spam_indicators?(content) do
    spam_patterns = [
      ~r/crypto|bitcoin|nft|token/i,
      ~r/follow.*back|f4f|followback/i,
      ~r/check.*out.*link|click.*link/i,
      ~r/\$\$\$|💰|🤑/,
      ~r/urgent|limited.*time|act.*now/i
    ]
    
    Enum.any?(spam_patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end
  
  defp build_tweet_url(username, tweet_id) do
    if username do
      "https://twitter.com/#{username}/status/#{tweet_id}"
    else
      "https://twitter.com/i/status/#{tweet_id}"
    end
  end
  
  defp get_bearer_token do
    Application.get_env(:dashboard_gen, :twitter)[:bearer_token] ||
    System.get_env("TWITTER_BEARER_TOKEN")
  end
end