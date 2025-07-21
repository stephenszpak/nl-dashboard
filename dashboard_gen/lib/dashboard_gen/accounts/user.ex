defmodule DashboardGen.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias DashboardGen.Accounts.UserSession
  alias DashboardGen.Conversations.Conversation

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:onboarded_at, :utc_datetime)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    
    # New fields
    field(:username, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:avatar_url, :string)
    field(:preferences, :map, default: %{})
    field(:last_active_at, :utc_datetime)
    field(:timezone, :string, default: "UTC")

    # Associations
    has_many(:sessions, UserSession)
    has_many(:conversations, Conversation, preload_order: [desc: :last_activity_at])

    timestamps()
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation, :username, :first_name, :last_name])
    |> validate_required([:email, :password, :password_confirmation])
    |> validate_format(:email, ~r/@/)
    |> validate_confirmation(:password)
    |> validate_length(:password, min: 6)
    |> validate_username()
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
    |> put_last_active()
  end

  @doc """
  Profile update changeset for non-sensitive fields.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :first_name, :last_name, :avatar_url, :preferences, :timezone])
    |> validate_username()
    |> unique_constraint(:username)
    |> put_last_active()
  end

  @doc """
  Activity tracking changeset.
  """
  def activity_changeset(user) do
    user
    |> change(%{last_active_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  @doc """
  Returns the user's display name (first name + last name or username or email).
  """
  def display_name(%__MODULE__{} = user) do
    cond do
      user.first_name && user.last_name ->
        "#{user.first_name} #{user.last_name}"
      user.username ->
        user.username
      true ->
        user.email |> String.split("@") |> List.first()
    end
  end

  @doc """
  Returns the user's initials for avatar display.
  """
  def initials(%__MODULE__{} = user) do
    cond do
      user.first_name && user.last_name ->
        "#{String.first(user.first_name)}#{String.first(user.last_name)}"
      user.username ->
        user.username |> String.first() |> String.upcase()
      true ->
        user.email |> String.first() |> String.upcase()
    end
  end

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/, 
         message: "can only contain letters, numbers, hyphens, and underscores")
  end

  defp put_password_hash(changeset) do
    if password = get_change(changeset, :password) do
      change(changeset, hashed_password: Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end

  defp put_last_active(changeset) do
    change(changeset, last_active_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
