defmodule DashboardGenWeb.SessionController do
  use DashboardGenWeb, :controller
  alias DashboardGen.Accounts

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        case Accounts.create_session(user.id) do
          {:ok, session} ->
            conn
            |> put_session(:session_token, session.token)
            |> put_session(:user_id, user.id)
            |> redirect(to: "/dashboard")

          {:error, _} ->
            conn
            |> put_flash(:error, "Unable to create session. Please try again.")
            |> redirect(to: "/login")
        end

      :error ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: "/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid request format")
    |> redirect(to: "/login")
  end
end