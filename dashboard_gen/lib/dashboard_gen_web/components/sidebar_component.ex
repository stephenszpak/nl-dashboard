defmodule DashboardGenWeb.SidebarComponent do
  use DashboardGenWeb, :html

  attr(:collapsed, :boolean, default: false)

  def sidebar(assigns) do
    ~H"""
    <aside
      class={[
        "bg-white border-r transition-all transform duration-200 flex flex-col md:translate-x-0",
        "absolute inset-y-0 left-0 z-20 md:static",
        @collapsed && "-translate-x-full md:w-16",
        !@collapsed && "translate-x-0 w-60"
      ]}
    >
      <div class="flex items-center justify-between px-4 py-3 border-b">
        <span :if={!@collapsed} class="font-semibold">DashboardGen</span>
        <button phx-click="toggle_sidebar" class="text-gray-500" aria-label="Toggle sidebar">
          <%= if @collapsed, do: "▶", else: "◀" %>
        </button>
      </div>
      <nav class="flex-1 p-2 space-y-1">
        <Phoenix.Component.link navigate={~p"/"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md">
          📊 <span :if={!@collapsed}>Dashboard</span>
        </Phoenix.Component.link>
        <Phoenix.Component.link navigate={~p"/saved"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md">
          💾 <span :if={!@collapsed}>Saved Views</span>
        </Phoenix.Component.link>
        <Phoenix.Component.link navigate={~p"/settings"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md">
          ⚙️ <span :if={!@collapsed}>Settings</span>
        </Phoenix.Component.link>
        <Phoenix.Component.link navigate={~p"/uploads"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md">
          📁 <span :if={!@collapsed}>Uploads</span>
        </Phoenix.Component.link>
      </nav>
    </aside>
    """
  end
end
