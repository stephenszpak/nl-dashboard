defmodule DashboardGen.Conversations.ConversationMessage do
  use Ecto.Schema
  import Ecto.Changeset
  alias DashboardGen.Conversations.Conversation

  schema "conversation_messages" do
    field(:role, :string) # "user" or "assistant"
    field(:content, :string)
    field(:prompt_type, :string) # "competitive_intelligence", "analytics", etc.
    field(:response_time_ms, :integer)
    field(:tokens_used, :integer)
    field(:model_used, :string)
    field(:metadata, :map, default: %{})
    field(:is_regenerated, :boolean, default: false)

    belongs_to(:conversation, Conversation)
    belongs_to(:parent_message, __MODULE__, foreign_key: :parent_message_id)
    has_many(:child_messages, __MODULE__, foreign_key: :parent_message_id)

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :role, :content, :prompt_type, :response_time_ms, :tokens_used, 
      :model_used, :metadata, :is_regenerated, :conversation_id, :parent_message_id
    ])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant"])
    |> validate_length(:content, min: 1)
    |> validate_number(:response_time_ms, greater_than: 0)
    |> validate_number(:tokens_used, greater_than: 0)
    |> assoc_constraint(:conversation)
    |> assoc_constraint(:parent_message)
  end

  @doc """
  Creates a changeset for a user message.
  """
  def user_message_changeset(conversation_id, content, prompt_type \\ nil) do
    %__MODULE__{}
    |> changeset(%{
      role: "user",
      content: content,
      conversation_id: conversation_id,
      prompt_type: prompt_type
    })
  end

  @doc """
  Creates a changeset for an assistant message.
  """
  def assistant_message_changeset(conversation_id, content, opts \\ []) do
    attrs = %{
      role: "assistant",
      content: content,
      conversation_id: conversation_id,
      response_time_ms: Keyword.get(opts, :response_time_ms),
      tokens_used: Keyword.get(opts, :tokens_used),
      model_used: Keyword.get(opts, :model_used),
      metadata: Keyword.get(opts, :metadata, %{}),
      parent_message_id: Keyword.get(opts, :parent_message_id)
    }

    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc """
  Creates a regenerated assistant message.
  """
  def regenerated_message_changeset(original_message, new_content, opts \\ []) do
    attrs = %{
      role: "assistant",
      content: new_content,
      conversation_id: original_message.conversation_id,
      parent_message_id: original_message.parent_message_id,
      is_regenerated: true,
      response_time_ms: Keyword.get(opts, :response_time_ms),
      tokens_used: Keyword.get(opts, :tokens_used),
      model_used: Keyword.get(opts, :model_used),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    %__MODULE__{}
    |> changeset(attrs)
  end
end