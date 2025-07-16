defmodule DashboardGenWeb.SavedLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Saved Views")}
  end
end
