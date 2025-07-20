defmodule DashboardGen.Scrapers do
  @moduledoc """
  Orchestrates running Python scrapers and storing the results.
  """

  alias DashboardGen.Repo
  alias DashboardGen.Scrapers.Insight

  @scripts ["scrape_all.py"]

  priv_dir = :code.priv_dir(:dashboard_gen) |> to_string()
  @scripts_path Path.join([priv_dir, "python", "scrapers"])

  @doc "Run all configured scraper scripts and company press releases"
  def scrape_all do
    IO.puts("🚀 Starting scraper pipeline...")

    Enum.each(@scripts, fn script ->
      case scrape_source(script) do
        {:ok, _result} -> IO.puts("✅ #{script} succeeded")
        {:error, reason} -> IO.inspect(reason, label: "❌ #{script} failed")
      end
    end)
  end

  @doc "Run a single scraper script by filename"
  def scrape_source(script) when is_binary(script) do
    path = Path.join(@scripts_path, script)
    IO.puts("🚀 #{path}")

    case File.exists?(path) do
      true -> run_script(path, Path.rootname(script))
      false -> {:error, :not_found}
    end
  end

  defp run_script(path, source, args \\ []) do
    IO.inspect("Running: #{path} #{Enum.join(args, " ")}")
    {output, status} = System.cmd("python3", [path | args], stderr_to_stdout: true)
    IO.inspect({status, output}, label: "Script result")

    case Jason.decode(output) do
      {:ok, data} ->
        IO.inspect(data, label: "Parsed data")

        %Insight{}
        |> Insight.changeset(%{source: source, data: data})
        |> Repo.insert()

      {:error, reason} ->
        IO.inspect(reason, label: "JSON parse error")
        IO.inspect(output, label: "Raw scraper output")
        {:error, {reason, output}}
    end
  end
end
