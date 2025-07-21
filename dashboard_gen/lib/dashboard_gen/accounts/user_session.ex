defmodule DashboardGen.Accounts.UserSession do
  use Ecto.Schema
  import Ecto.Changeset
  alias DashboardGen.Accounts.User

  @session_duration_days 7

  schema "user_sessions" do
    field(:token, :string)
    field(:device_info, :string)
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:expires_at, :utc_datetime)
    field(:last_used_at, :utc_datetime)
    field(:is_active, :boolean, default: true)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:token, :device_info, :ip_address, :user_agent, :expires_at, :last_used_at, :is_active, :user_id])
    |> validate_required([:token, :expires_at, :last_used_at, :user_id])
    |> unique_constraint(:token)
    |> assoc_constraint(:user)
  end

  @doc """
  Creates a new session for a user with a 7-day expiration.
  """
  def create_changeset(user_id, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, @session_duration_days, :day)
    
    token = generate_session_token()
    
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      token: token,
      expires_at: expires_at,
      last_used_at: now,
      device_info: Keyword.get(opts, :device_info),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      is_active: true
    })
  end

  @doc """
  Updates the last_used_at timestamp for session activity tracking.
  """
  def activity_changeset(session) do
    session
    |> changeset(%{last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  @doc """
  Deactivates a session.
  """
  def deactivate_changeset(session) do
    session
    |> changeset(%{is_active: false})
  end

  @doc """
  Extends the session expiration by another 7 days.
  """
  def extend_changeset(session) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    new_expires_at = DateTime.add(now, @session_duration_days, :day)
    
    session
    |> changeset(%{
      expires_at: new_expires_at,
      last_used_at: now
    })
  end

  @doc """
  Checks if a session is valid (active and not expired).
  """
  def valid?(session) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    session.is_active && DateTime.compare(session.expires_at, now) == :gt
  end

  @doc """
  Generates a secure random session token.
  """
  def generate_session_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Returns the session duration in days.
  """
  def session_duration_days, do: @session_duration_days
end