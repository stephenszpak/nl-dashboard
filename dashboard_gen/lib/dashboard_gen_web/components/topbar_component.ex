defmodule DashboardGenWeb.TopbarComponent do
  use DashboardGenWeb, :html

  attr(:collapsed, :boolean, default: false)

  def topbar(assigns) do
    ~H"""
    <div class="md:hidden flex items-center justify-between px-4 py-3 border-b bg-white">
      <button phx-click="toggle_sidebar" aria-label="Open sidebar" class="text-xl">☰</button>
      <span class="font-semibold">DashboardGen</span>
    </div>
    """
  end
end
