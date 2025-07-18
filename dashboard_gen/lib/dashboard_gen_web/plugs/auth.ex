defmodule DashboardGenWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller
  alias DashboardGen.Accounts

  def fetch_current_user(conn, _opts) do
    user = get_session(conn, :user_id) && Accounts.get_user(get_session(conn, :user_id))
    assign(conn, :current_user, user)
  end

  def require_authenticated(%{assigns: %{current_user: nil}} = conn, _opts) do
    conn
    |> redirect(to: "/login")
    |> halt()
  end

  def require_authenticated(conn, _opts), do: conn
end
