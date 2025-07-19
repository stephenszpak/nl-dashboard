defmodule DashboardGen.Repo.Migrations.CreateInsights do
  use Ecto.Migration

  def change do
    create table(:insights) do
      add :source, :string
      add :data, {:array, :map}
      timestamps(updated_at: false)
    end
  end
end
