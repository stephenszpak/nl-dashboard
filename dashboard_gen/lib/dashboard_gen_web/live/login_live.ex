defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :root}
  use DashboardGenWeb, :html

  def mount(_params, _session, socket) do
    csrf_token = Plug.CSRFProtection.get_csrf_token()
    {:ok, assign(socket, csrf_token: csrf_token)}
  end
end
