defmodule DashboardGen.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:onboarded_at, :utc_datetime)

    timestamps()
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> validate_required([:email, :password, :password_confirmation])
    |> validate_format(:email, ~r/@/)
    |> validate_confirmation(:password)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    if password = get_change(changeset, :password) do
      change(changeset, hashed_password: Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end
end
