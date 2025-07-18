defmodule DashboardGen.Accounts do
  @moduledoc false
  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
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
end
