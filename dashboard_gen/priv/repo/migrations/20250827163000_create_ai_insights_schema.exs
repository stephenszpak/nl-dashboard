defmodule DashboardGen.Repo.Migrations.CreateAiInsightsSchema do
  use Ecto.Migration

  def change do
    create table(:ai_insights) do
      add :company, :string, null: false
      add :category, :string
      add :title, :string, null: false
      add :summary, :text
      add :detail, :text
      add :period_start, :date
      add :period_end, :date
      add :freshness_days, :integer
      add :tags, {:array, :string}, default: []
      add :entities, {:array, :string}, default: []
      add :sentiment_score, :float
      add :impact_score, :float
      add :provenance, :map, default: %{}
      add :evidence, :map, default: %{}
      add :raw_json, :map, default: %{}

      timestamps()
    end

    create index(:ai_insights, [:company])
    create index(:ai_insights, [:category])
    create index(:ai_insights, [:company, :category])
    create index(:ai_insights, [:company, :period_start])

    create table(:ai_events) do
      add :company, :string, null: false
      add :event_type, :string
      add :title, :string, null: false
      add :description, :text
      add :occurred_on, :date
      add :time_start, :date
      add :time_end, :date
      add :tags, {:array, :string}, default: []
      add :entities, {:array, :string}, default: []
      add :sentiment_score, :float
      add :impact_score, :float
      add :provenance, :map, default: %{}
      add :evidence, :map, default: %{}
      add :raw_json, :map, default: %{}

      timestamps()
    end

    create index(:ai_events, [:company])
    create index(:ai_events, [:event_type])
    create index(:ai_events, [:company, :occurred_on])

    create table(:ai_topics) do
      add :name, :string, null: false
      add :description, :text
      add :aliases, {:array, :string}, default: []
      timestamps()
    end
    create unique_index(:ai_topics, [:name])

    create table(:ai_topic_links) do
      add :topic_id, references(:ai_topics, on_delete: :delete_all), null: false
      add :link_type, :string, null: false # "insight" | "event"
      add :link_id, :integer, null: false
      add :company, :string
      add :weight, :float
      add :metadata, :map, default: %{}
      timestamps()
    end
    create index(:ai_topic_links, [:topic_id])
    create index(:ai_topic_links, [:link_type, :link_id])

    create table(:ai_snapshots) do
      add :company, :string, null: false
      add :period, :string
      add :summary, :text
      add :key_metrics, :map, default: %{}
      add :top_risks, :map, default: %{}
      add :top_opportunities, :map, default: %{}
      add :period_start, :date
      add :period_end, :date
      add :provenance, :map, default: %{}
      add :evidence, :map, default: %{}
      add :raw_json, :map, default: %{}
      timestamps()
    end

    create index(:ai_snapshots, [:company])
    create index(:ai_snapshots, [:company, :period])
  end
end

