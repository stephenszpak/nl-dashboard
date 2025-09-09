defmodule DashboardGen.AI.AiSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_snapshots" do
    field :company, :string
    field :period, :string
    field :summary, :string
    field :key_metrics, :map, default: %{}
    field :top_risks, :map, default: %{}
    field :top_opportunities, :map, default: %{}
    field :period_start, :date
    field :period_end, :date
    field :provenance, :map, default: %{}
    field :evidence, :map, default: %{}
    field :raw_json, :map, default: %{}
    timestamps()
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:company])
  end
end

