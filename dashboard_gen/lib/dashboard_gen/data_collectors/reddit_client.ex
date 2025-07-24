defmodule DashboardGen.DataCollectors.RedditClient do
  @moduledoc """
  Reddit API client for collecting mentions and sentiment data.
  Uses Reddit's free API with authentication.
  """
  
  require Logger
  alias DashboardGen.Sentiment
  
  @base_url "https://oauth.reddit.com"
  @auth_url "https://www.reddit.com/api/v1/access_token"
  @user_agent "DashboardGen:sentiment-monitor:v1.0.0 (by /u/your_username)"
  
  def collect_mentions(companies) when is_list(companies) do
    case get_access_token() do
      {:ok, token} ->
        collect_with_token(companies, token)
      {:error, reason} ->
        Logger.warning("Reddit authentication failed: #{reason}")
        {:error, "Reddit auth failed"}
    end
  end
  
  defp collect_with_token(companies, token) do
    results = Enum.map(companies, fn company ->
      case collect_company_mentions(company, token) do
        {:ok, count} -> 
          Logger.info("Collected #{count} Reddit mentions for #{company}")
          count
        {:error, reason} -> 
          Logger.error("Failed to collect Reddit mentions for #{company}: #{reason}")
          0
      end
      # Respect Reddit's rate limits
      Process.sleep(2000)
    end)
    
    total = Enum.sum(results)
    {:ok, total}
  end
  
  defp collect_company_mentions(company, token) do
    # Search in relevant subreddits
    subreddits = get_relevant_subreddits(company)
    
    total_count = Enum.reduce(subreddits, 0, fn subreddit, acc ->
      case search_subreddit(company, subreddit, token) do
        {:ok, posts} ->
          processed = process_and_store_posts(posts, company)
          acc + processed
        {:error, _reason} ->
          acc
      end
    end)
    
    {:ok, total_count}
  end
  
  defp search_subreddit(company, subreddit, token) do
    query = build_search_query(company)
    url = "#{@base_url}/r/#{subreddit}/search.json"
    
    params = %{
      "q" => query,
      "restrict_sr" => "1",
      "sort" => "new",
      "limit" => "25",
      "t" => "week" # Last week's posts
    }
    
    headers = [
      {"Authorization", "bearer #{token}"},
      {"User-Agent", @user_agent}
    ]
    
    case HTTPoison.get(url, headers, params: params) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => %{"children" => posts}}} ->
            {:ok, Enum.map(posts, & &1["data"])}
          {:ok, response} ->
            Logger.warning("Unexpected Reddit response: #{inspect(response)}")
            {:ok, []}
          {:error, reason} ->
            {:error, "JSON decode error: #{reason}"}
        end
      {:ok, %{status_code: status, body: body}} ->
        Logger.error("Reddit API error #{status}: #{body}")
        {:error, "API error: #{status}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
  
  defp get_relevant_subreddits(company) do
    base_subreddits = ["investing", "stocks", "SecurityAnalysis", "ValueInvesting", "financialindependence"]
    
    company_specific = case String.downcase(company) do
      "blackrock" -> ["etfs", "Bogleheads"]
      "vanguard" -> ["Bogleheads", "etfs", "portfolios"]  
      "fidelity" -> ["fidelityinvestments", "portfolios"]
      "goldman sachs" -> ["wallstreetbets", "SecurityAnalysis"]
      _ -> ["etfs"]
    end
    
    base_subreddits ++ company_specific
  end
  
  defp build_search_query(company) do
    # Build search terms for Reddit
    base_terms = [company]
    
    additional_terms = case String.downcase(company) do
      "blackrock" -> ["BLK", "iShares"]
      "vanguard" -> ["VTI", "VTSAX", "bogle"]
      "state street" -> ["STT", "SPDR"]
      "fidelity" -> ["FXAIX", "fidelity"]
      "goldman sachs" -> ["GS", "goldman"]
      _ -> []
    end
    
    (base_terms ++ additional_terms)
    |> Enum.join(" OR ")
  end
  
  defp process_and_store_posts(posts, company) do
    Enum.reduce(posts, 0, fn post, acc ->
      case process_post(post, company) do
        {:ok, _sentiment_data} -> acc + 1
        {:error, _reason} -> acc
      end
    end)
  end
  
  defp process_post(post, company) do
    # Extract content from post
    title = post["title"] || ""
    selftext = post["selftext"] || ""
    content = "#{title} #{selftext}" |> String.trim()
    
    # Skip removed/deleted posts or posts that are too short
    if String.length(content) < 20 or 
       String.contains?(content, ["[removed]", "[deleted]"]) or
       spam_indicators?(content) do
      {:error, "Post filtered out"}
    else
      # Analyze sentiment
      case Sentiment.analyze_sentiment(content, company: company, source: "reddit") do
        {:ok, analysis} ->
          attrs = %{
            source: "reddit",
            source_id: post["id"],
            company: company,
            content: String.slice(content, 0, 1000), # Truncate very long posts
            content_type: if(post["selftext"] != "", do: "post", else: "title"),
            author: post["author"],
            url: "https://reddit.com#{post["permalink"]}",
            platform_data: %{
              subreddit: post["subreddit"],
              score: post["score"],
              upvote_ratio: post["upvote_ratio"],
              num_comments: post["num_comments"],
              created_utc: post["created_utc"],
              over_18: post["over_18"] || false,
              post_hint: post["post_hint"]
            },
            sentiment_score: analysis.sentiment_score,
            sentiment_label: analysis.sentiment_label,
            confidence: analysis.confidence,
            topics: analysis.topics,
            emotions: analysis.emotions,
            analysis_model: analysis.analysis_model,
            language: "en",
            country: "US" # Reddit is primarily US-based
          }
          
          Sentiment.create_sentiment_data(attrs)
        {:error, reason} ->
          {:error, "Sentiment analysis failed: #{reason}"}
      end
    end
  end
  
  defp spam_indicators?(content) do
    spam_patterns = [
      ~r/buy.*now|limited.*offer/i,
      ~r/click.*here|visit.*site/i,
      ~r/make.*money.*fast/i,
      ~r/dm.*me|send.*pm/i
    ]
    
    Enum.any?(spam_patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
  end
  
  defp get_access_token do
    client_id = get_client_id()
    client_secret = get_client_secret()
    username = get_username()
    password = get_password()
    
    if client_id && client_secret && username && password do
      authenticate(client_id, client_secret, username, password)
    else
      {:error, "Reddit credentials not configured"}
    end
  end
  
  defp authenticate(client_id, client_secret, username, password) do
    auth_string = Base.encode64("#{client_id}:#{client_secret}")
    
    headers = [
      {"Authorization", "Basic #{auth_string}"},
      {"User-Agent", @user_agent},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]
    
    body = "grant_type=password&username=#{username}&password=#{password}"
    
    case HTTPoison.post(@auth_url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"access_token" => token}} -> {:ok, token}
          {:ok, response} -> {:error, "Unexpected auth response: #{inspect(response)}"}
          {:error, reason} -> {:error, "JSON decode error: #{reason}"}
        end
      {:ok, %{status_code: status, body: body}} ->
        {:error, "Auth failed with status #{status}: #{body}"}
      {:error, reason} ->
        {:error, "Auth request failed: #{inspect(reason)}"}
    end
  end
  
  defp get_client_id do
    Application.get_env(:dashboard_gen, :reddit)[:client_id] ||
    System.get_env("REDDIT_CLIENT_ID")
  end
  
  defp get_client_secret do
    Application.get_env(:dashboard_gen, :reddit)[:client_secret] ||
    System.get_env("REDDIT_CLIENT_SECRET")
  end
  
  defp get_username do
    Application.get_env(:dashboard_gen, :reddit)[:username] ||
    System.get_env("REDDIT_USERNAME")
  end
  
  defp get_password do
    Application.get_env(:dashboard_gen, :reddit)[:password] ||
    System.get_env("REDDIT_PASSWORD")
  end
end