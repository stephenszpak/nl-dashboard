defmodule DashboardGen.Repo.Migrations.CreateInsightSummaries do
  use Ecto.Migration

  def change do
    create table(:insight_summaries) do
      add :company, :string
      add :summary, :text

      timestamps(updated_at: false)
    end

    create index(:insight_summaries, [:company])
  end
end
