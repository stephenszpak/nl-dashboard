defmodule DashboardGen.Uploads.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "uploads" do
    field :name, :string
    field :headers, :map
    field :data, {:array, :map}

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:name, :headers, :data])
    |> validate_required([:name, :headers, :data])
  end
end
