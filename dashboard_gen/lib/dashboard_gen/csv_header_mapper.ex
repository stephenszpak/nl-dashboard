defmodule DashboardGen.CSVHeaderMapper do
  @moduledoc """
  Helper utilities for normalising GPT generated field names to the
  headers used in our CSV datasets.

  GPT chart specifications use lowercase snake_case while the CSV files
  have title-cased, space separated headers. This module provides
  convenience functions for translating between the two.
  """

  @mapping %{
    "campaign" => "Campaign",
    "cost_per_click" => "Cost Per Click",
    "impressions" => "Impressions",
    "clicks" => "Clicks",
    "conversions" => "Conversions",
    "ad_spend" => "Ad Spend",
    "month" => "Month",
    "ctr" => "CTR"
  }

  @doc """
  Returns the CSV header corresponding to the given GPT field name.
  Unknown fields are humanised by capitalising each word.
  """
  @spec normalize_field(String.t()) :: String.t()
  def normalize_field(field) when is_binary(field) do
    Map.get(@mapping, field, humanize(field))
  end

  defp humanize(field) do
    field
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Remaps the keys of each row in the given list using `normalize_field/1`.
  """
  @spec remap_headers([map()]) :: [map()]
  def remap_headers(rows) when is_list(rows) do
    Enum.map(rows, fn row ->
      Enum.reduce(row, %{}, fn {key, value}, acc ->
        Map.put(acc, normalize_field(key), value)
      end)
    end)
  end
end
