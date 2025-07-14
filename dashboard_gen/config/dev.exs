import Config

# Configure your database
config :dashboard_gen, DashboardGen.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dashboard_gen_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :dashboard_gen, DashboardGenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "DEV_SECRET_KEY_BASE",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :dashboard_gen, DashboardGenWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/dashboard_gen_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, level: :debug

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
