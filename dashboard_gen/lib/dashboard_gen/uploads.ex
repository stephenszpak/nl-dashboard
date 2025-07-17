defmodule DashboardGen.Uploads do
  @moduledoc """
  Context for managing uploaded CSV datasets.
  """

  import Ecto.Query, warn: false
  alias DashboardGen.Repo

  alias DashboardGen.Uploads.Upload
  alias NimbleCSV.RFC4180, as: CSV

  @doc "List all uploads ordered by inserted_at descending"
  def list_uploads do
    Repo.all(from u in Upload, order_by: [desc: u.inserted_at])
  end

  @doc "Get the most recent upload"
  def latest_upload do
    Repo.one(from u in Upload, order_by: [desc: u.inserted_at], limit: 1)
  end

  @doc "Create an upload record from a CSV file path"
  def create_upload(path, name \\ nil) do
    with {:ok, %{headers: headers, rows: rows}} <- parse_csv(path) do
      %Upload{}
      |> Upload.changeset(%{name: name || Path.basename(path), headers: headers, data: rows})
      |> Repo.insert()
    end
  end

  @doc "Parse a CSV file returning headers map and rows"
  def parse_csv(path) do
    with {:ok, content} <- File.read(path) do
      rows = CSV.parse_string(content)

      case rows do
        [] -> {:error, "CSV is empty"}
        [header_row | data_rows] ->
          normalized = Enum.map(header_row, &normalize_header/1)
          headers = Enum.zip(normalized, header_row) |> Map.new()

          if Enum.all?(data_rows, &(length(&1) == length(header_row))) do
            maps =
              Enum.map(data_rows, fn row ->
                Enum.zip(normalized, row)
                |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, convert_value(v)) end)
              end)

            {:ok, %{headers: headers, rows: maps}}
          else
            {:error, "CSV rows have inconsistent number of fields"}
          end
      end
    end
  end

  defp convert_value(value) when is_binary(value) do
    cond do
      value == "" -> nil
      Integer.parse(value) != :error and match?({_, ""}, Integer.parse(value)) ->
        {int, _} = Integer.parse(value)
        int
      Float.parse(value) != :error and match?({_, ""}, Float.parse(value)) ->
        {float, _} = Float.parse(value)
        float
      true -> value
    end
  end

  defp convert_value(value), do: value

  def normalize_header(header) do
    header
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[\s-]+/, "_")
  end
end
