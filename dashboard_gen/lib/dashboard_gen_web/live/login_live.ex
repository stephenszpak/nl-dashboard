defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :root}
  use DashboardGenWeb, :html

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
