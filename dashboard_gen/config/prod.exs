import Config

# Do not print debug messages in production
config :logger, level: :info

config :dashboard_gen, DashboardGenWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Database config is in runtime.exs to use environment variables
