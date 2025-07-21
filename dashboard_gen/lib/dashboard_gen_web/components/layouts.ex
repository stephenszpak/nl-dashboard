defmodule DashboardGenWeb.Layouts do
  use DashboardGenWeb, :html

  import DashboardGenWeb.LayoutComponents
  import DashboardGenWeb.SidebarComponent

  embed_templates("layouts/*")
end
