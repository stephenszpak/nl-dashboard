defmodule DashboardGenWeb.PageController do
  use DashboardGenWeb, :controller

  def home(conn, _params) do
    text(conn, "Hello from DashboardGen! The server is working.")
  end
end
