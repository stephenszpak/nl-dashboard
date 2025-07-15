import Config

# Load environment variables from .env file if present
if File.exists?(Path.expand("../.env", __DIR__)) do
  Dotenvy.source!(Path.expand("../.env", __DIR__))
end

if config_env() == :prod do
  config :dashboard_gen, DashboardGenWeb.Endpoint,
    server: true,
    url: [host: System.get_env("PHX_HOST", "example.com"), port: 443],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :openai, api_key: System.fetch_env!("OPENAI_API_KEY")
else
  if api_key = System.get_env("OPENAI_API_KEY") do
    config :openai, api_key: api_key
  end
end
