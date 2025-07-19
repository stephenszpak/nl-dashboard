defmodule DashboardGenWeb.SettingsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Settings", collapsed: false)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end
end
