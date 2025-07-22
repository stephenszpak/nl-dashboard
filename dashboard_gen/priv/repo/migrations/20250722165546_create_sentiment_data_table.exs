defmodule DashboardGen.Repo.Migrations.CreateSentimentDataTable do
  use Ecto.Migration

  def change do
    create table(:sentiment_data) do
      add :source, :string, null: false                    # twitter, reddit, linkedin, etc.
      add :source_id, :string, null: false                 # unique ID from source platform
      add :company, :string, null: false                   # company being analyzed
      add :content, :text, null: false                     # original text content
      add :content_type, :string, default: "post"          # post, comment, review, etc.
      add :author, :string                                  # username/handle (optional)
      add :url, :string                                     # link to original content
      add :platform_data, :map, default: %{}               # additional platform-specific data
      
      # Sentiment analysis results
      add :sentiment_score, :float, null: false            # -1.0 to 1.0 scale
      add :sentiment_label, :string, null: false           # positive, negative, neutral
      add :confidence, :float                               # confidence score 0-1
      add :analysis_model, :string, default: "openai"      # model used for analysis
      add :topics, {:array, :string}, default: []          # extracted topics/keywords
      add :emotions, :map, default: %{}                     # emotion breakdown
      
      # Metadata
      add :language, :string, default: "en"                # detected language
      add :country, :string                                 # geographic data if available
      add :processed_at, :utc_datetime                      # when analysis was completed
      add :is_valid, :boolean, default: true               # flag for data quality
      add :analysis_version, :string, default: "1.0"       # version of analysis pipeline
      
      timestamps()
    end

    # Indexes for performance
    create index(:sentiment_data, [:company])
    create index(:sentiment_data, [:source])
    create index(:sentiment_data, [:sentiment_label])
    create index(:sentiment_data, [:inserted_at])
    create index(:sentiment_data, [:company, :inserted_at])
    create index(:sentiment_data, [:company, :sentiment_score])
    create unique_index(:sentiment_data, [:source, :source_id])  # prevent duplicates
  end
end
