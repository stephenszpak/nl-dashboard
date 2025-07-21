defmodule DashboardGen.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false, default: "New Conversation"
      add :description, :text
      add :last_activity_at, :utc_datetime, null: false
      add :message_count, :integer, default: 0
      add :is_archived, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:conversations, [:user_id])
    create index(:conversations, [:user_id, :last_activity_at])
    create index(:conversations, [:last_activity_at])
  end
end