defmodule DashboardGenWeb.Router do
  use DashboardGenWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {DashboardGenWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", DashboardGenWeb do
    pipe_through(:browser)

    live("/", DashboardLive)
  end
end
