defmodule DashboardGen.Insights.TopicSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "insight_summaries" do
    field :company, :string
    field :summary, :string

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [:company, :summary])
    |> validate_required([:company, :summary])
  end
end
