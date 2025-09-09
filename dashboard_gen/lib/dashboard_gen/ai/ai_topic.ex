defmodule DashboardGen.AI.AiTopic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_topics" do
    field :name, :string
    field :description, :string
    field :aliases, {:array, :string}, default: []
    timestamps()
  end

  def changeset(topic, attrs) do
    topic
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
  end
end

