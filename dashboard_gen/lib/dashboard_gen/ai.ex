defmodule DashboardGen.AI do
  @moduledoc """
  Context for AI-first insights, events, topics, and snapshots.
  """
  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.AI.{AiInsight, AiEvent, AiTopic, AiTopicLink, AiSnapshot}

  # Insights
  def create_insight(attrs) do
    %AiInsight{} |> AiInsight.changeset(attrs) |> Repo.insert()
  end

  def create_event(attrs) do
    %AiEvent{} |> AiEvent.changeset(attrs) |> Repo.insert()
  end

  def create_snapshot(attrs) do
    %AiSnapshot{} |> AiSnapshot.changeset(attrs) |> Repo.insert()
  end

  def get_or_create_topic(name, attrs \\ %{}) when is_binary(name) do
    case Repo.get_by(AiTopic, name: String.trim(name)) do
      nil -> %AiTopic{} |> AiTopic.changeset(Map.put(attrs, :name, name)) |> Repo.insert()
      topic -> {:ok, topic}
    end
  end

  def link_topic(topic_id, link_type, link_id, attrs \\ %{}) do
    %AiTopicLink{}
    |> AiTopicLink.changeset(Map.merge(%{topic_id: topic_id, link_type: link_type, link_id: link_id}, attrs))
    |> Repo.insert()
  end

  # Queries
  def latest_snapshot(company) when is_binary(company) do
    from(s in AiSnapshot,
      where: s.company == ^company,
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def latest_snapshot_or_nil(company) do
    try do
      latest_snapshot(company)
    rescue
      _ -> nil
    end
  end

  def list_events(company, opts \\ []) do
    days_back = Keyword.get(opts, :days_back, 30)
    limit = Keyword.get(opts, :limit, 100)
    cutoff = Date.utc_today() |> Date.add(-days_back)

    from(e in AiEvent,
      where: e.company == ^company and (is_nil(e.occurred_on) or e.occurred_on >= ^cutoff),
      order_by: [desc: e.occurred_on, desc: e.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def list_events_or_empty(company, opts \\ []) do
    try do
      list_events(company, opts)
    rescue
      _ -> []
    end
  end

  def list_insights(company, category, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    from(i in AiInsight,
      where: i.company == ^company and i.category == ^category,
      order_by: [desc: i.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def list_topics(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    from(t in AiTopic,
      order_by: [asc: t.name],
      limit: ^limit
    )
    |> Repo.all()
  end
end
