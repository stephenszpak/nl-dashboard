defmodule DashboardGen.Scrapers do
  @moduledoc """
  Orchestrates running Python scrapers and storing the results.
  """

  alias DashboardGen.Repo
  alias DashboardGen.Scrapers.Insight

  @scripts ["competitor_sites.py", "press_releases.py", "social_media.py"]

  @scripts_path Path.join(:code.priv_dir(:dashboard_gen), ["python", "scrapers"])

  @doc "Run all configured scraper scripts"
  def scrape_all do
    Enum.each(@scripts, &scrape_source/1)
  end

  @doc "Run a single scraper script by filename"
  def scrape_source(script) when is_binary(script) do
    path = Path.join(@scripts_path, script)

    case File.exists?(path) do
      true -> run_script(path, Path.rootname(script))
      false -> {:error, :not_found}
    end
  end

  defp run_script(path, source) do
    {output, _} = System.cmd("python3", [path], stderr_to_stdout: true)

    with {:ok, data} <- Jason.decode(output) do
      %Insight{}
      |> Insight.changeset(%{source: source, data: data})
      |> Repo.insert()
    else
      {:error, reason} -> {:error, {reason, output}}
    end
  end
end
