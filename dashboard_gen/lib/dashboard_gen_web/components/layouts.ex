defmodule DashboardGenWeb.Layouts do
  use DashboardGenWeb, :html

  import DashboardGenWeb.SidebarComponent
  import DashboardGenWeb.TopbarComponent

  embed_templates("layouts/*")
end
