defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :auth}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  alias DashboardGen.Accounts

  def mount(_params, session, socket) do
    csrf_token = Map.get(session, "_csrf_token")
    {:ok, assign(socket, error: nil, page_title: "Login", csrf_token: csrf_token)}
  end

end
