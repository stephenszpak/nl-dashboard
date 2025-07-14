defmodule DashboardGen.CSVLoader do
  @moduledoc """
  Utilities for loading CSV files located under `priv/data`.

  The `load/1` function returns a list of maps keyed by the CSV headers.
  Headers are normalised by trimming whitespace and downcasing.
  """

  alias NimbleCSV.RFC4180, as: CSV

  @data_path Path.join(:code.priv_dir(:dashboard_gen), "data")

  @doc """
  Reads the given CSV file from `priv/data` and returns the parsed rows as a
  list of maps.
  """
  @spec load(String.t()) :: [map()]
  def load(filename) when is_binary(filename) do
    filename
    |> build_path()
    |> File.stream!()
    |> CSV.parse_stream()
    |> Enum.to_list()
    |> to_maps()
  end

  @doc """
  Lists the available CSV data sources under `priv/data`.
  """
  @spec available_data_sources() :: [String.t()]
  def available_data_sources do
    case File.ls(@data_path) do
      {:ok, files} -> Enum.filter(files, &String.ends_with?(&1, ".csv"))
      {:error, _} -> []
    end
  end

  defp build_path(filename), do: Path.join(@data_path, filename)

  defp to_maps([]), do: []
  defp to_maps([headers | rows]) do
    headers = Enum.map(headers, &normalize_header/1)

    Enum.map(rows, fn row ->
      headers
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  defp normalize_header(hdr) do
    hdr
    |> String.trim()
    |> String.downcase()
  end
end
