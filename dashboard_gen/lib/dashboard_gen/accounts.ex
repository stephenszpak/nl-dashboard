defmodule DashboardGen.Accounts do
  @moduledoc false
  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Accounts.{User, UserSession}

  ## Users

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def track_user_activity(%User{} = user) do
    user
    |> User.activity_changeset()
    |> Repo.update()
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email(email),
         true <- Bcrypt.verify_pass(password, user.hashed_password) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  def mark_onboarded(%User{} = user) do
    user
    |> Ecto.Changeset.change(onboarded_at: DateTime.utc_now())
    |> Repo.update()
  end

  ## Sessions

  @doc """
  Creates a new session for a user with 7-day expiration.
  """
  def create_session(user_id, opts \\ []) do
    user_id
    |> UserSession.create_changeset(opts)
    |> Repo.insert()
  end

  @doc """
  Gets a session by token and validates it's still active.
  """
  def get_session_by_token(token) when is_binary(token) do
    case Repo.get_by(UserSession, token: token) |> Repo.preload(:user) do
      %UserSession{} = session ->
        if UserSession.valid?(session) do
          # Update last_used_at
          {:ok, updated_session} = update_session_activity(session)
          {:ok, updated_session}
        else
          {:error, :expired}
        end
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates session activity timestamp.
  """
  def update_session_activity(%UserSession{} = session) do
    session
    |> UserSession.activity_changeset()
    |> Repo.update()
  end

  @doc """
  Extends a session expiration by another 7 days.
  """
  def extend_session(%UserSession{} = session) do
    session
    |> UserSession.extend_changeset()
    |> Repo.update()
  end

  @doc """
  Deactivates a session (logout).
  """
  def deactivate_session(%UserSession{} = session) do
    session
    |> UserSession.deactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Deactivates a session by token.
  """
  def deactivate_session_by_token(token) when is_binary(token) do
    case Repo.get_by(UserSession, token: token) do
      %UserSession{} = session -> deactivate_session(session)
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Deactivates all sessions for a user.
  """
  def deactivate_all_user_sessions(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    from(s in UserSession, where: s.user_id == ^user_id and s.is_active == true)
    |> Repo.update_all(set: [is_active: false, updated_at: now])
  end

  @doc """
  Cleans up expired sessions.
  """
  def cleanup_expired_sessions do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    from(s in UserSession, where: s.expires_at < ^now or s.is_active == false)
    |> Repo.delete_all()
  end

  @doc """
  Gets active sessions for a user.
  """
  def list_user_sessions(user_id) do
    from(s in UserSession,
      where: s.user_id == ^user_id and s.is_active == true,
      order_by: [desc: s.last_used_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a valid session and returns the user. Helper for auth plug.
  """
  def get_valid_session(token) when is_binary(token) do
    case get_session_by_token(token) do
      {:ok, session} -> session
      _ -> nil
    end
  end
end
