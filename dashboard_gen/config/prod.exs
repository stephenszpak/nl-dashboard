import Config

config :dashboard_gen, DashboardGen.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :dashboard_gen, DashboardGenWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443],
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info
