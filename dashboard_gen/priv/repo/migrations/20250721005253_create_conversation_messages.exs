defmodule DashboardGen.Repo.Migrations.CreateConversationMessages do
  use Ecto.Migration

  def change do
    create table(:conversation_messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :role, :string, null: false # "user" or "assistant"
      add :content, :text, null: false
      add :prompt_type, :string # "competitive_intelligence", "analytics", etc.
      add :response_time_ms, :integer
      add :tokens_used, :integer
      add :model_used, :string
      add :metadata, :map, default: %{}
      add :is_regenerated, :boolean, default: false
      add :parent_message_id, references(:conversation_messages), null: true

      timestamps()
    end

    create index(:conversation_messages, [:conversation_id])
    create index(:conversation_messages, [:conversation_id, :inserted_at])
    create index(:conversation_messages, [:role])
    create index(:conversation_messages, [:parent_message_id])
  end
end