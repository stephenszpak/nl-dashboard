defmodule DashboardGen.Scrapers do
  @moduledoc """
  Orchestrates running Python scrapers and storing the results.
  """

  alias DashboardGen.Repo
  alias DashboardGen.Scrapers.Insight

  @scripts ["competitor_sites.py", "social_media.py"]
  @press_release_companies ~w(blackstone jpmorgan)

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

    Enum.each(@press_release_companies, fn company ->
      case run_press_release_script(company) do
        {:ok, _} -> IO.puts("✅ press_releases.py (#{company}) succeeded")
        {:error, reason} -> IO.inspect(reason, label: "❌ press_releases.py (#{company}) failed")
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

  defp run_script(path, source) do
    IO.inspect("Running: #{path}")
    {output, status} = System.cmd("python3", [path], stderr_to_stdout: true)
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

  defp run_press_release_script(company) do
    path = Path.join(@scripts_path, "press_releases.py")

    case File.exists?(path) do
      true ->
        {_, _status} = System.cmd("python3", [path, "--company", company], stderr_to_stdout: true)

        output_path = Path.join(File.cwd!(), "scrape_output.json")

        case File.read(output_path) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, data} ->
                %Insight{}
                |> Insight.changeset(%{source: company, data: data})
                |> Repo.insert()

              {:error, reason} ->
                IO.inspect(reason, label: "JSON decode error (#{company})")
                IO.inspect(json, label: "Raw output (#{company})")
                {:error, {reason, json}}
            end

          {:error, reason} ->
            {:error, {:file_read_failed, reason}}
        end

      false ->
        {:error, :press_release_script_not_found}
    end
  end
end
