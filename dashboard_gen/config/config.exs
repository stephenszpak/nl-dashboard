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

# Data Collectors Configuration
config :dashboard_gen, :data_collectors,
  companies: ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs"],
  social_sources: [:twitter, :reddit],
  news_sources: [:newsapi, :google_news, :yahoo_finance],
  collection_intervals: %{
    social_media: :timer.minutes(15),
    news: :timer.hours(1)
  },
  api_limits: %{
    twitter: %{requests_per_15min: 300, requests_per_day: 10000},
    reddit: %{requests_per_minute: 60, requests_per_day: 1000},
    newsapi: %{requests_per_day: 1000}
  },
  quality_filters: %{
    min_content_length: 10,
    max_content_length: 5000,
    spam_detection: true,
    duplicate_window_hours: 24
  }

# API Configuration (use environment variables in production)
config :dashboard_gen, :twitter,
  bearer_token: System.get_env("TWITTER_BEARER_TOKEN")

config :dashboard_gen, :reddit,
  client_id: System.get_env("REDDIT_CLIENT_ID"),
  client_secret: System.get_env("REDDIT_CLIENT_SECRET"),
  username: System.get_env("REDDIT_USERNAME"),
  password: System.get_env("REDDIT_PASSWORD")

config :dashboard_gen, :newsapi,
  api_key: System.get_env("NEWSAPI_KEY")

import_config "#{config_env()}.exs"
