defmodule DashboardGenWeb.PageController do
  use DashboardGenWeb, :controller

  def home(conn, _params) do
    render(conn, :index)
  end
end
