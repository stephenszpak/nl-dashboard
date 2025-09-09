defmodule DashboardGen.AI.AiTopicLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_topic_links" do
    field :link_type, :string
    field :link_id, :integer
    field :company, :string
    field :weight, :float
    field :metadata, :map, default: %{}
    belongs_to :topic, DashboardGen.AI.AiTopic
    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:topic_id, :link_type, :link_id])
  end
end

