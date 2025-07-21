defmodule DashboardGen.Conversations do
  @moduledoc """
  The Conversations context - handles chat history and conversation management.
  """

  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Conversations.{Conversation, ConversationMessage}
  alias DashboardGen.Accounts.User

  ## Conversations

  @doc """
  Returns the list of conversations for a user, ordered by last activity.
  """
  def list_user_conversations(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    include_archived = Keyword.get(opts, :include_archived, false)

    query = 
      from c in Conversation,
        where: c.user_id == ^user_id,
        order_by: [desc: c.last_activity_at],
        limit: ^limit

    query = 
      if include_archived do
        query
      else
        from c in query, where: c.is_archived == false
      end

    Repo.all(query)
  end

  @doc """
  Gets a single conversation with messages.
  """
  def get_conversation!(id) do
    Repo.get!(Conversation, id)
    |> Repo.preload(messages: :parent_message)
  end

  @doc """
  Gets a conversation belonging to a specific user.
  """
  def get_user_conversation(user_id, conversation_id) do
    case Repo.get_by(Conversation, id: conversation_id, user_id: user_id) do
      nil -> {:error, :not_found}
      conversation -> {:ok, Repo.preload(conversation, messages: :parent_message)}
    end
  end
  
  @doc """
  Gets a conversation by ID for a specific user (returns struct or nil).
  """
  def get_conversation(conversation_id, user_id) do
    Repo.get_by(Conversation, id: conversation_id, user_id: user_id)
  end
  
  @doc """
  Gets the most recent conversation for a user.
  """
  def get_most_recent_conversation(user_id) do
    from(c in Conversation,
      where: c.user_id == ^user_id and c.is_archived == false,
      order_by: [desc: c.last_activity_at],
      limit: 1
    )
    |> Repo.one()
  end
  
  @doc """
  Adds a message to an existing conversation.
  """
  def add_message(conversation_id, content, role, opts \\ []) do
    response_time_ms = Keyword.get(opts, :response_time_ms)
    parent_message_id = Keyword.get(opts, :parent_message_id)
    
    message_attrs = %{
      conversation_id: conversation_id,
      content: content,
      role: role,
      response_time_ms: response_time_ms,
      parent_message_id: parent_message_id
    }
    
    %ConversationMessage{}
    |> ConversationMessage.changeset(message_attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Update conversation activity and message count
        conversation = Repo.get!(Conversation, conversation_id)
        {:ok, _} = update_conversation_activity(conversation)
        {:ok, message}
      error ->
        error
    end
  end
  
  @doc """
  Creates a conversation message.
  """
  def create_conversation_message(attrs) do
    %ConversationMessage{}
    |> ConversationMessage.changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Updates conversation activity and message count.
  """
  def update_conversation_activity(conversation) do
    conversation
    |> Conversation.activity_changeset()
    |> Repo.update()
  end

  @doc """
  Creates a new conversation for a user.
  """
  def create_conversation(user_id, attrs \\ %{}) do
    user_id
    |> Conversation.new_changeset(attrs[:title])
    |> Repo.insert()
  end

  @doc """
  Creates a conversation with an initial user message.
  """
  def create_conversation_with_message(user_id, content, prompt_type \\ nil) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:conversation, Conversation.new_changeset(user_id))
    |> Ecto.Multi.run(:message, fn repo, %{conversation: conversation} ->
      ConversationMessage.user_message_changeset(conversation.id, content, prompt_type)
      |> repo.insert()
    end)
    |> Ecto.Multi.run(:update_conversation, fn repo, %{conversation: conversation, message: _message} ->
      # Generate title from first message and update activity
      title = Conversation.generate_title_from_content(content)
      
      conversation
      |> Conversation.changeset(%{title: title, message_count: 1, last_activity_at: DateTime.utc_now()})
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_conversation: conversation, message: message}} ->
        {:ok, %{conversation | messages: [message]}}
      {:error, _operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a conversation.
  """
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Archives a conversation.
  """
  def archive_conversation(%Conversation{} = conversation) do
    update_conversation(conversation, %{is_archived: true})
  end

  @doc """
  Deletes a conversation and all its messages.
  """
  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  ## Messages

  @doc """
  Gets the messages for a conversation in chronological order.
  """
  def list_conversation_messages(conversation_id) do
    from(m in ConversationMessage,
      where: m.conversation_id == ^conversation_id,
      order_by: [asc: m.inserted_at],
      preload: [:parent_message]
    )
    |> Repo.all()
  end

  @doc """
  Adds a user message to a conversation.
  """
  def add_user_message(conversation_id, content, prompt_type \\ nil) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:message, ConversationMessage.user_message_changeset(conversation_id, content, prompt_type))
    |> Ecto.Multi.run(:update_conversation, fn repo, %{message: _message} ->
      conversation = repo.get!(Conversation, conversation_id)
      
      conversation
      |> Conversation.activity_changeset()
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} -> {:ok, message}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Adds an assistant message to a conversation.
  """
  def add_assistant_message(conversation_id, content, opts \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:message, ConversationMessage.assistant_message_changeset(conversation_id, content, opts))
    |> Ecto.Multi.run(:update_conversation, fn repo, %{message: _message} ->
      conversation = repo.get!(Conversation, conversation_id)
      
      conversation
      |> Conversation.activity_changeset()
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} -> {:ok, message}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Regenerates an assistant message.
  """
  def regenerate_message(%ConversationMessage{role: "assistant"} = original_message, new_content, opts \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:new_message, ConversationMessage.regenerated_message_changeset(original_message, new_content, opts))
    |> Ecto.Multi.run(:update_conversation, fn repo, %{new_message: _message} ->
      conversation = repo.get!(Conversation, original_message.conversation_id)
      
      conversation
      |> Conversation.activity_changeset()
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{new_message: message}} -> {:ok, message}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Gets a message by id.
  """
  def get_message!(id) do
    Repo.get!(ConversationMessage, id)
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%ConversationMessage{} = message) do
    Repo.delete(message)
  end

  ## Search and Analytics

  @doc """
  Searches conversations by title or message content.
  """
  def search_conversations(user_id, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    
    search_term = "%#{query}%"
    
    # First find conversations with matching titles
    title_matches = from(c in Conversation,
      where: c.user_id == ^user_id and c.is_archived == false and ilike(c.title, ^search_term),
      select: c.id
    )
    
    # Then find conversations with matching message content
    message_matches = from(m in ConversationMessage,
      join: c in Conversation, on: m.conversation_id == c.id,
      where: c.user_id == ^user_id and c.is_archived == false and ilike(m.content, ^search_term),
      select: c.id,
      distinct: true
    )
    
    # Combine the results
    conversation_ids = Repo.all(title_matches) ++ Repo.all(message_matches)
    |> Enum.uniq()
    
    # Get the conversations
    from(c in Conversation,
      where: c.id in ^conversation_ids,
      order_by: [desc: c.last_activity_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets conversation statistics for a user.
  """
  def get_user_stats(user_id) do
    conversations_query = from c in Conversation, where: c.user_id == ^user_id
    messages_query = from m in ConversationMessage, 
                     join: c in Conversation, on: m.conversation_id == c.id,
                     where: c.user_id == ^user_id

    %{
      total_conversations: Repo.aggregate(conversations_query, :count),
      total_messages: Repo.aggregate(messages_query, :count),
      archived_conversations: Repo.aggregate(from(c in conversations_query, where: c.is_archived == true), :count),
      avg_messages_per_conversation: Repo.aggregate(
        from(c in conversations_query, select: c.message_count), :avg
      ) || 0
    }
  end

  # Import Ecto.Multi for transaction support
  alias Ecto.Multi
end