defmodule DashboardGen.Repo.Migrations.CreateUploads do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :name, :string
      add :headers, :map
      add :data, {:array, :map}

      timestamps(updated_at: false)
    end
  end
end
