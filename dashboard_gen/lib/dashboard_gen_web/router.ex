defmodule DashboardGenWeb.Router do
  use DashboardGenWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(DashboardGenWeb.Plugs.Auth, :fetch_current_user)
    plug(:put_root_layout, {DashboardGenWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :require_auth do
    plug(DashboardGenWeb.Plugs.Auth, :require_authenticated)
  end

  scope "/", DashboardGenWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    live("/register", RegisterLive)
    live("/login", LoginLive)
    post("/login", AuthController, :create)
    delete("/logout", AuthController, :delete)
  end

  scope "/", DashboardGenWeb do
    pipe_through([:browser, :require_auth])

    live("/dashboard", DashboardLive)
    live("/onboarding", OnboardingLive)
    live("/saved", SavedLive)
    live("/settings", SettingsLive)
    live("/uploads", UploadsLive)
  end
end
