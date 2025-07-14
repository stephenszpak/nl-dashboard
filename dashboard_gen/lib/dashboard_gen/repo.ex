defmodule DashboardGen.Repo do
  use Ecto.Repo,
    otp_app: :dashboard_gen,
    adapter: Ecto.Adapters.Postgres
end
