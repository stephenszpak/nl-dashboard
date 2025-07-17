defmodule DashboardGen.Uploads do
  @moduledoc """
  Context for managing uploaded CSV datasets.
  """

  import Ecto.Query, warn: false
  alias DashboardGen.Repo

  alias DashboardGen.Uploads.Upload
  alias NimbleCSV.RFC4180, as: CSV
  require Logger

  @canonical_headers [
    "date",
    "campaign_id",
    "campaign_name",
    "cost_per_click",
    "impressions",
    "clicks",
    "conversions",
    "source"
  ]

  @doc "List all uploads ordered by inserted_at descending"
  def list_uploads do
    Repo.all(from(u in Upload, order_by: [desc: u.inserted_at]))
  end

  @doc "Get the most recent upload"
  def latest_upload do
    Repo.one(from(u in Upload, order_by: [desc: u.inserted_at], limit: 1))
  end

  @doc "Create an upload record from a CSV file path"
  def create_upload(path, name \\ nil) do
    with {:ok, %{headers: headers, rows: rows}} <- parse_csv(path) do
      name = if is_nil(name) or name == "", do: "Untitled Upload", else: name

      %Upload{}
      |> Upload.changeset(%{name: name, headers: headers, data: rows})
      |> Repo.insert()
    end
  end

  @doc "Parse a CSV file returning headers map and rows"
  def parse_csv(path) do
    with {:ok, content} <- File.read(path) do
      content =
        case content do
          <<239, 187, 191, rest::binary>> -> rest
          _ -> content
        end

      rows =
        content
        |> String.replace("\r\n", "\n")
        |> String.replace("\r", "\n")
        |> String.split("\n")
        |> Enum.drop_while(&(&1 |> String.trim() == ""))
        |> Enum.join("\n")
        |> CSV.parse_string()

      Logger.debug("Parsed rows: #{inspect(rows)}")

      case rows do
        [] ->
          {:error, "CSV is empty"}

        [header_row | data_rows] ->
          Logger.debug("raw header row: #{inspect(header_row)}")

          canonical = Enum.map(header_row, &canonical_header/1)
          Logger.debug("inferred headers: #{inspect(canonical)}")

          headers =
            Enum.zip(canonical, header_row)
            |> Enum.reduce(%{}, fn {canon, raw}, acc ->
              if canon in @canonical_headers, do: Map.put_new(acc, canon, raw), else: acc
            end)

          missing =
            Enum.filter(@canonical_headers, fn key ->
              not Map.has_key?(headers, key)
            end)

          cond do
            missing != [] ->
              {:error, "Invalid CSV: missing required column '#{List.first(missing)}'"}

            Enum.all?(data_rows, &(length(&1) == length(header_row))) ->
              maps =
                Enum.map(data_rows, fn row ->
                  Enum.zip(canonical, row)
                  |> Enum.reduce(%{}, fn {k, v}, acc ->
                    if k in @canonical_headers do
                      Map.put(acc, k, convert_value(v))
                    else
                      acc
                    end
                  end)
                end)

              {:ok, %{headers: headers, rows: maps}}

            true ->
              {:error, "CSV rows have inconsistent number of fields"}
          end
      end
    end
  end

  defp convert_value(value) when is_binary(value) do
    cond do
      value == "" ->
        nil

      Integer.parse(value) != :error and match?({_, ""}, Integer.parse(value)) ->
        {int, _} = Integer.parse(value)
        int

      Float.parse(value) != :error and match?({_, ""}, Float.parse(value)) ->
        {float, _} = Float.parse(value)
        float

      true ->
        value
    end
  end

  defp convert_value(value), do: value

  defp blank_row?(row) do
    Enum.all?(row, fn cell -> String.trim(cell) == "" end)
  end

  defp header_looks_like_data?([first | _]) do
    Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, String.trim_leading(first, "\uFEFF") |> String.trim())
  end

  defp header_looks_like_data?(_), do: false

  defp canonical_header(header) do
    normalized = normalize_header(header)

    cond do
      normalized in @canonical_headers -> normalized
      Regex.match?(~r/^cmp\d+$/, normalized) -> "campaign_id"
      Regex.match?(~r/^campaign_\d+$/, normalized) -> "campaign_id"
      String.contains?(normalized, "campaign") and String.contains?(normalized, "id") ->
        "campaign_id"
      String.contains?(normalized, "campaign") and String.contains?(normalized, "name") ->
        "campaign_name"
      normalized == "cpc" or (String.contains?(normalized, "cost") and String.contains?(normalized, "click")) ->
        "cost_per_click"
      String.contains?(normalized, "impression") -> "impressions"
      String.contains?(normalized, "click") -> "clicks"
      String.contains?(normalized, "conversion") -> "conversions"
      normalized == "google_ads" or String.contains?(normalized, "source") -> "source"
      true -> normalized
    end
  end

  def normalize_header(header) do
    header
    |> String.trim_leading("\uFEFF")
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[\s-]+/, "_")
  end

  @doc """
  Resolve a loosely matching field name to one of the dataset headers. Matching
  is case-insensitive and works on substrings. If multiple headers match, an
  exact match is preferred, otherwise the longest matching header is returned.
  Returns `nil` when no match can be found.
  """
  @spec resolve_field(String.t() | nil, map()) :: String.t() | nil
  def resolve_field(field, headers)

  def resolve_field(nil, _headers), do: nil

  def resolve_field(field, headers) when is_binary(field) and is_map(headers) do
    normalized = normalize_header(field)
    keys = Map.keys(headers)

    cond do
      normalized in keys ->
        normalized

      true ->
        keys
        |> Enum.filter(fn key ->
          String.contains?(key, normalized) or String.contains?(normalized, key)
        end)
        |> Enum.sort_by(&String.length/1, :desc)
        |> List.first()
    end
  end

  def resolve_field(_, _), do: nil
end
