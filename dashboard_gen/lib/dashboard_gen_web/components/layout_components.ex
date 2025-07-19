defmodule DashboardGenWeb.LayoutComponents do
  use DashboardGenWeb, :html

  @doc """
  Sidebar navigation
  """
  attr(:collapsed, :boolean, default: false)

  def sidebar(assigns) do
    ~H"""
    <aside class={[if(@collapsed, do: "w-16", else: "w-60"), "bg-white border-r min-h-screen transition-all flex flex-col"]}>
      <div class="flex items-center justify-between px-4 py-3 font-semibold border-b">
        <span :if={!@collapsed}>DashboardGen</span>
        <button phx-click="toggle_sidebar" aria-label="Toggle sidebar" class="text-gray-600 hover:text-gray-800 p-2">
          <%= if @collapsed, do: "➡️", else: "⬅️" %>
        </button>
      </div>
      <nav class="flex-1 p-2 space-y-1">
        <.link navigate={~p"/"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
          <i class="fa-solid fa-chart-bar"></i> <%= unless @collapsed, do: "Dashboard" %>
        </.link>
        <.link navigate={~p"/saved"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
          <i class="fa-solid fa-save"></i> <%= unless @collapsed, do: "Saved Views" %>
        </.link>
        <.link navigate={~p"/insights"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
          <i class="fa-solid fa-newspaper"></i> <%= unless @collapsed, do: "Insights" %>
        </.link>
        <.link navigate={~p"/settings"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
          <i class="fa-solid fa-gear"></i> <%= unless @collapsed, do: "Settings" %>
        </.link>
        <.link navigate={~p"/uploads"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
          <i class="fa-solid fa-folder-open"></i> <%= unless @collapsed, do: "Uploads" %>
        </.link>
      </nav>
    </aside>
    """
  end

  @doc """
  Mobile top bar
  """
  attr(:page_title, :string, required: true)
  attr(:show_menu, :boolean, default: true)

  def topbar(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-white border-b px-4 py-3 md:hidden">
      <button :if={@show_menu} phx-click="toggle_sidebar" class="p-2 rounded-md hover:bg-gray-100">☰</button>
      <h2 class="text-sm font-semibold"><%= @page_title %></h2>
      <div />
    </div>
    """
  end

  @doc """
  Alert banner
  """
  attr(:alerts, :string, default: nil)

  def alert_banner(assigns) do
    ~H"""
    <div class="bg-yellow-50 border-l-4 border-yellow-400 text-yellow-900 p-4 rounded-md text-sm">
      <strong><i class="fa-solid fa-triangle-exclamation text-yellow-600"></i> Alert:</strong>
      <ul class="list-disc pl-6 space-y-1">
        <%= for line <- String.split(@alerts || "", "\n", trim: true) do %>
          <li><%= line %></li>
        <% end %>
      </ul>
    </div>
    """
  end

  @doc """
  Insight buttons group
  """
  attr(:summary, :boolean, default: false)
  attr(:loading, :boolean, default: false)

  def insight_buttons(assigns) do
    ~H"""
    <div class="mt-4 space-x-2">
      <%= if !@summary && !@loading do %>
        <.button variant="secondary" phx-click="generate_summary" class="rounded-full">Generate Insight</.button>
      <% end %>
      <.button variant="secondary" phx-click="explain_this" class="rounded-full">Explain This</.button>
      <.button variant="secondary" phx-click="why_this" class="rounded-full">Why Did This Happen?</.button>
    </div>
    """
  end
end
