defmodule DashboardGen.AI.AiEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_events" do
    field :company, :string
    field :event_type, :string
    field :title, :string
    field :description, :string
    field :occurred_on, :date
    field :time_start, :date
    field :time_end, :date
    field :tags, {:array, :string}, default: []
    field :entities, {:array, :string}, default: []
    field :sentiment_score, :float
    field :impact_score, :float
    field :provenance, :map, default: %{}
    field :evidence, :map, default: %{}
    field :raw_json, :map, default: %{}
    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:company, :title])
  end
end

