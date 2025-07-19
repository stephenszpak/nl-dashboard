import Config

config :dashboard_gen,
  ecto_repos: [DashboardGen.Repo]

config :dashboard_gen, DashboardGenWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DashboardGenWeb.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: DashboardGen.PubSub,
  live_view: [signing_salt: "SA1tSaLt"]

config :esbuild,
  # Bump the bundled esbuild version to a modern release since 0.7.0 is no
  # longer distributed via npm. 0.17.11 is compatible with the current
  # `esbuild` mix dependency and is available for download.
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.3.0",
  default: [
    args:
      ~w(--config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :dashboard_gen, DashboardGen.Scheduler,
  jobs: [
    {"@daily", {DashboardGen.Scrapers, :scrape_all, []}}
  ]

import_config "#{config_env()}.exs"
