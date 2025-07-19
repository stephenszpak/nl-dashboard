defmodule DashboardGen.Scrapers.Insight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "insights" do
    field(:source, :string)
    field(:data, {:array, :map})
    timestamps(updated_at: false)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:source, :data])
    |> validate_required([:source, :data])
  end
end
