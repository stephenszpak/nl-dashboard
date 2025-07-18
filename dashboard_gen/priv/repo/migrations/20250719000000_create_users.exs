defmodule DashboardGen.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :onboarded_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
