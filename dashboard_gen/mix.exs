defmodule DashboardGen.MixProject do
  use Mix.Project

  def project do
    [
      app: :dashboard_gen,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {DashboardGen.Application, []},
      extra_applications: [:logger, :runtime_tools, :req]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_view, "~> 0.20.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_dashboard, "~> 0.8.1"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:floki, ">= 0.34.0", only: :test},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.22"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
      {:nimble_csv, "~> 1.2"},
      {:vega_lite, "~> 0.1.8"},
      {:openai, "~> 0.5"},
      {:dotenvy, "~> 0.8"},
      {:req, "~> 0.4"},
      {:bcrypt_elixir, "~> 3.0"},
      {:quantum, "~> 3.5"},
      {:httpoison, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd --cd assets npm install"],
      "assets.deploy": [
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
