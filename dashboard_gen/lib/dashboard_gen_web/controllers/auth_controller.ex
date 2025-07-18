defmodule DashboardGenWeb.AuthController do
  use DashboardGenWeb, :controller

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end
end
