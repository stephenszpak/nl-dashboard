# Sentiment Analysis Sample Data
# Run with: mix run priv/repo/seeds_sentiment.exs

import Ecto.Query
alias DashboardGen.Sentiment

# Sample companies
companies = ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"]

# Sample social media posts
sample_posts = [
  # Positive sentiment
  %{content: "BlackRock's new ESG fund is exactly what we need for sustainable investing! 🌱", score: 0.8, topics: ["ESG", "sustainability", "investing"]},
  %{content: "Love how Vanguard keeps fees so low. Best value in the market!", score: 0.7, topics: ["fees", "value", "market"]},
  %{content: "State Street's diversity initiative is making real change in finance", score: 0.6, topics: ["diversity", "finance", "change"]},
  %{content: "Fidelity's customer service is outstanding. Quick response and helpful!", score: 0.9, topics: ["customer service", "support", "helpful"]},
  %{content: "Goldman Sachs' research reports are always insightful and well-researched", score: 0.5, topics: ["research", "reports", "insightful"]},
  
  # Neutral sentiment
  %{content: "BlackRock announced new fund launches this quarter", score: 0.0, topics: ["fund", "launches", "quarter"]},
  %{content: "Vanguard's market cap reached new levels this year", score: 0.1, topics: ["market cap", "levels", "year"]},
  %{content: "State Street published their quarterly earnings report", score: -0.1, topics: ["earnings", "report", "quarterly"]},
  %{content: "Fidelity expanding into cryptocurrency trading platforms", score: 0.0, topics: ["cryptocurrency", "trading", "platforms"]},
  %{content: "Goldman Sachs hiring more analysts for tech sector coverage", score: 0.1, topics: ["hiring", "analysts", "tech"]},
  
  # Negative sentiment
  %{content: "BlackRock's fees are getting too high compared to competitors", score: -0.5, topics: ["fees", "high", "competitors"]},
  %{content: "Disappointed with Vanguard's app update. So many bugs and crashes!", score: -0.7, topics: ["app", "bugs", "crashes"]},
  %{content: "State Street's performance has been lackluster this quarter", score: -0.4, topics: ["performance", "lackluster", "quarter"]},
  %{content: "Fidelity's website is confusing and hard to navigate", score: -0.6, topics: ["website", "confusing", "navigate"]},
  %{content: "Goldman Sachs involved in another controversy. When will they learn?", score: -0.8, topics: ["controversy", "ethics", "reputation"]},
]

# Sample sources
sources = ["twitter", "reddit", "linkedin", "facebook", "news"]

# Generate sentiment data for the past 30 days
IO.puts("🌱 Seeding sentiment analysis data...")

for company <- companies do
  IO.puts("  Creating data for #{company}...")
  
  for day <- -30..0 do
    date = Date.add(Date.utc_today(), day)
    base_datetime = DateTime.new!(date, ~T[12:00:00])
    
    # Generate 3-15 posts per day per company
    post_count = Enum.random(3..15)
    
    for i <- 1..post_count do
      # Pick a random sample post and modify it
      sample = Enum.random(sample_posts)
      source = Enum.random(sources)
      
      # Add some time variation throughout the day
      hour_offset = Enum.random(0..23)
      minute_offset = Enum.random(0..59)
      post_datetime = DateTime.add(base_datetime, hour_offset * 3600 + minute_offset * 60, :second)
      
      # Modify content to mention the company
      content = String.replace(sample.content, ~r/(BlackRock|Vanguard|State Street|Fidelity|Goldman Sachs)/, company)
      
      # Add some random variation to sentiment score
      score_variation = (Enum.random(-20..20) / 100.0)
      final_score = max(-1.0, min(1.0, sample.score + score_variation))
      
      attrs = %{
        source: source,
        source_id: "#{source}_#{company}_#{day}_#{i}",
        company: company,
        content: content,
        content_type: "post",
        author: "user#{Enum.random(1000..9999)}",
        url: "https://#{source}.com/post/#{Enum.random(100000..999999)}",
        sentiment_score: final_score,
        sentiment_label: cond do
          final_score > 0.1 -> "positive"
          final_score < -0.1 -> "negative"
          true -> "neutral"
        end,
        confidence: 0.7 + Enum.random(0..30) / 100.0,
        topics: sample.topics,
        emotions: %{
          "joy" => if(final_score > 0.3, do: Enum.random(60..90) / 100.0, else: Enum.random(0..20) / 100.0),
          "anger" => if(final_score < -0.3, do: Enum.random(60..90) / 100.0, else: Enum.random(0..20) / 100.0),
          "fear" => if(final_score < -0.5, do: Enum.random(40..70) / 100.0, else: Enum.random(0..30) / 100.0),
          "surprise" => Enum.random(0..40) / 100.0,
          "sadness" => if(final_score < -0.2, do: Enum.random(30..60) / 100.0, else: Enum.random(0..20) / 100.0)
        },
        language: "en",
        country: Enum.random(["US", "UK", "CA", "AU", "DE"]),
        inserted_at: DateTime.truncate(post_datetime, :second),
        updated_at: DateTime.truncate(post_datetime, :second)
      }
      
      case Sentiment.create_sentiment_data(attrs) do
        {:ok, _} -> :ok
        {:error, changeset} -> 
          IO.puts("    ⚠️  Error creating sentiment data: #{inspect(changeset.errors)}")
      end
    end
  end
end

# Get some stats
total_records = DashboardGen.Repo.aggregate(DashboardGen.Sentiment.SentimentData, :count, :id)
IO.puts("\n✅ Sentiment data seeding complete!")
IO.puts("📊 Created #{total_records} sentiment records")

for company <- companies do
  company_count = DashboardGen.Repo.aggregate(
    from(s in DashboardGen.Sentiment.SentimentData, where: s.company == ^company),
    :count,
    :id
  )
  IO.puts("   #{company}: #{company_count} records")
end

IO.puts("\n🚀 You can now test the sentiment dashboard at /sentiment")