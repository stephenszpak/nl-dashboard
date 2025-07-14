import Config

# Configure your database
config :dashboard_gen, DashboardGen.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dashboard_gen_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test.
config :dashboard_gen, DashboardGenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "TEST_SECRET_KEY_BASE",
  server: false

config :logger, level: :warning
