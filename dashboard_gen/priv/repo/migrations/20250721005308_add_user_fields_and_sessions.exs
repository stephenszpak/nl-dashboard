defmodule DashboardGen.Repo.Migrations.AddUserFieldsAndSessions do
  use Ecto.Migration

  def change do
    # Add additional fields to users table
    alter table(:users) do
      add :username, :string
      add :first_name, :string
      add :last_name, :string
      add :avatar_url, :string
      add :preferences, :map, default: %{}
      add :last_active_at, :utc_datetime
      add :timezone, :string, default: "UTC"
    end

    # Create user_sessions table for 7-day session tokens
    create table(:user_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :device_info, :string
      add :ip_address, :string
      add :user_agent, :string
      add :expires_at, :utc_datetime, null: false
      add :last_used_at, :utc_datetime, null: false
      add :is_active, :boolean, default: true

      timestamps()
    end

    # Create unique indexes
    create unique_index(:users, [:username])
    # Email index already exists, skip it
    create unique_index(:user_sessions, [:token])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:expires_at])
    create index(:user_sessions, [:is_active])
  end
end