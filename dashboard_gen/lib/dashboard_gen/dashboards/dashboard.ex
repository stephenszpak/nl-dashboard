defmodule DashboardGen.Dashboards.Dashboard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dashboards" do
    field(:slug, :string)
    field(:prompt, :string)
    field(:response_json, :string)
    field(:insight_text, :string)
    timestamps()
  end

  def changeset(dashboard, attrs) do
    dashboard
    |> cast(attrs, [:slug, :prompt, :response_json, :insight_text])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end
end
