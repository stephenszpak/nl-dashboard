defmodule DashboardGen.Repo.Migrations.CreateDashboards do
  use Ecto.Migration

  def change do
    create table(:dashboards) do
      add :slug, :string
      add :prompt, :text
      add :response_json, :text
      add :insight_text, :text

      timestamps()
    end

    create unique_index(:dashboards, [:slug])
  end
end
