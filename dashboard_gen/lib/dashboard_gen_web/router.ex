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

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :require_auth do
    plug(DashboardGenWeb.Plugs.Auth, :require_authenticated)
  end

  scope "/", DashboardGenWeb do
    pipe_through(:browser)

    live("/register", RegisterLive)
    live("/login", LoginLive)
    delete("/logout", AuthController, :delete)
  end

  scope "/", DashboardGenWeb do
    pipe_through([:browser, :require_auth])

    live("/", DashboardLive)
    live("/dashboard", DashboardLive)
    live("/onboarding", OnboardingLive)
    live("/saved", SavedLive)
    live("/insights", CompetitorInsightsLive)
    live("/agent", AgentLive)
    live("/settings", SettingsLive)
    live("/uploads", UploadsLive)
  end

  # Analytics API routes
  scope "/api/analytics", DashboardGenWeb do
    pipe_through :api

    post "/webhook", AnalyticsController, :webhook
    post "/batch", AnalyticsController, :batch_upload
    post "/manual", AnalyticsController, :manual_entry
    get "/summary", AnalyticsController, :summary
    post "/sample", AnalyticsController, :generate_sample_data
    post "/realistic", AnalyticsController, :generate_realistic_data
  end
end
