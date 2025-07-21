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
    require Logger
    Logger.info("Starting scraper pipeline...")

    Enum.each(@scripts, fn script ->
      case scrape_source(script) do
        {:ok, _result} -> Logger.info("✅ #{script} succeeded")
        {:error, reason} -> Logger.error("❌ #{script} failed: #{inspect(reason)}")
      end
    end)
  end

  @doc "Run a single scraper script by filename"
  def scrape_source(script) when is_binary(script) do
    path = Path.join(@scripts_path, script)
    require Logger
    Logger.info("Running scraper: #{path}")

    case File.exists?(path) do
      true -> run_script(path, Path.rootname(script))
      false -> {:error, :not_found}
    end
  end

  defp run_script(path, source, args \\ []) do
    require Logger
    Logger.debug("Running: #{path} #{Enum.join(args, " ")}")
    
    # Use absolute path to virtual environment
    venv_python = "/Users/stephenszpak/workspace/nl-dashboard/dashboard_gen/venv/bin/python"
    
    {output, status} = System.cmd(venv_python, [path | args], stderr_to_stdout: false)
    Logger.debug("Script result: status=#{status}, output_length=#{String.length(output)}")

    case Jason.decode(output) do
      {:ok, data} ->
        Logger.debug("Successfully parsed #{map_size(data)} data items")

        %Insight{}
        |> Insight.changeset(%{source: source, data: data})
        |> Repo.insert()

      {:error, reason} ->
        Logger.error("JSON parse error: #{inspect(reason)}")
        Logger.error("Raw scraper output: #{String.slice(output, 0, 500)}...")
        {:error, {reason, output}}
    end
  end
end
