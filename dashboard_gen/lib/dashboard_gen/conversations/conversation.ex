defmodule DashboardGen.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  alias DashboardGen.Accounts.User
  alias DashboardGen.Conversations.ConversationMessage

  schema "conversations" do
    field(:title, :string, default: "New Conversation")
    field(:description, :string)
    field(:last_activity_at, :utc_datetime)
    field(:message_count, :integer, default: 0)
    field(:is_archived, :boolean, default: false)
    field(:metadata, :map, default: %{})

    belongs_to(:user, User)
    has_many(:messages, ConversationMessage, preload_order: [asc: :inserted_at])

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :description, :last_activity_at, :message_count, :is_archived, :metadata, :user_id])
    |> validate_required([:title, :last_activity_at, :user_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_number(:message_count, greater_than_or_equal_to: 0)
    |> assoc_constraint(:user)
  end

  @doc """
  Creates a changeset for starting a new conversation.
  """
  def new_changeset(user_id, title \\ nil) do
    title = title || "New Conversation"
    
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      title: title,
      last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second),
      message_count: 0
    })
  end

  @doc """
  Updates the last activity timestamp and message count.
  """
  def activity_changeset(conversation, message_count \\ nil) do
    count = message_count || conversation.message_count + 1
    
    conversation
    |> changeset(%{
      last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second),
      message_count: count
    })
  end

  @doc """
  Generates a smart title based on the first user message.
  """
  def generate_title_from_content(content) do
    content
    |> String.trim()
    |> String.slice(0, 50)
    |> case do
      "" -> "New Conversation"
      short_content -> 
        if String.length(short_content) == 50 do
          short_content <> "..."
        else
          short_content
        end
    end
  end
end