defmodule DashboardGen.Sentiment.SentimentData do
  @moduledoc """
  Schema for sentiment analysis data from social media and other sources.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "sentiment_data" do
    # Source information
    field :source, :string                    # twitter, reddit, linkedin, etc.
    field :source_id, :string                 # unique ID from source platform
    field :company, :string                   # company being analyzed
    field :content, :string                   # original text content
    field :content_type, :string, default: "post"  # post, comment, review, etc.
    field :author, :string                    # username/handle (optional)
    field :url, :string                       # link to original content
    field :platform_data, :map, default: %{} # additional platform-specific data
    
    # Sentiment analysis results
    field :sentiment_score, :float            # -1.0 to 1.0 scale
    field :sentiment_label, :string           # positive, negative, neutral
    field :confidence, :float                 # confidence score 0-1
    field :analysis_model, :string, default: "openai"  # model used for analysis
    field :topics, {:array, :string}, default: []      # extracted topics/keywords
    field :emotions, :map, default: %{}       # emotion breakdown
    
    # Metadata
    field :language, :string, default: "en"   # detected language
    field :country, :string                   # geographic data if available
    field :processed_at, :utc_datetime        # when analysis was completed
    field :is_valid, :boolean, default: true  # flag for data quality
    field :analysis_version, :string, default: "1.0"  # version of analysis pipeline
    
    timestamps()
  end
  
  @doc false
  def changeset(sentiment_data, attrs) do
    sentiment_data
    |> cast(attrs, [
      :source, :source_id, :company, :content, :content_type, :author, :url,
      :platform_data, :sentiment_score, :sentiment_label, :confidence, 
      :analysis_model, :topics, :emotions, :language, :country, :processed_at,
      :is_valid, :analysis_version
    ])
    |> validate_required([:source, :source_id, :company, :content, :sentiment_score, :sentiment_label])
    |> validate_inclusion(:sentiment_label, ["positive", "negative", "neutral"])
    |> validate_number(:sentiment_score, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:source, :source_id])
  end
  
  @doc """
  Determines sentiment label from score.
  """
  def score_to_label(score) when score > 0.1, do: "positive"
  def score_to_label(score) when score < -0.1, do: "negative"
  def score_to_label(_score), do: "neutral"
  
  @doc """
  Creates a changeset for new sentiment analysis.
  """
  def analysis_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:processed_at, DateTime.truncate(DateTime.utc_now(), :second))
    |> maybe_generate_label_from_score()
  end
  
  defp maybe_generate_label_from_score(changeset) do
    case get_change(changeset, :sentiment_score) do
      nil -> changeset
      score -> put_change(changeset, :sentiment_label, score_to_label(score))
    end
  end
end