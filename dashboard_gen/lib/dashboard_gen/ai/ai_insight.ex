defmodule DashboardGen.AI.AiInsight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_insights" do
    field :company, :string
    field :category, :string
    field :title, :string
    field :summary, :string
    field :detail, :string
    field :period_start, :date
    field :period_end, :date
    field :freshness_days, :integer
    field :tags, {:array, :string}, default: []
    field :entities, {:array, :string}, default: []
    field :sentiment_score, :float
    field :impact_score, :float
    field :provenance, :map, default: %{}
    field :evidence, :map, default: %{}
    field :raw_json, :map, default: %{}
    timestamps()
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:company, :title])
  end
end

