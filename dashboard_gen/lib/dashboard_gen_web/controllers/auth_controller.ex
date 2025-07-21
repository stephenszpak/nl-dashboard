defmodule DashboardGenWeb.AuthController do
  use DashboardGenWeb, :controller
  alias DashboardGen.Accounts

  def delete(conn, _params) do
    # Get session token and deactivate it
    if token = get_session(conn, :session_token) do
      Accounts.deactivate_session_by_token(token)
    end

    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
