defmodule DashboardGen.CSVHeaderMapper do
  @moduledoc """
  Provides utilities for translating raw CSV headers to the field
  names expected by GPT generated chart specifications.
  """

  @mapping %{
    "Month" => "Month",
    "Ad Spend" => "Ad Spend",
    "Conversions" => "Conversions",
    "CTR" => "CTR",
    "Impressions" => "Impressions",
    "Cost Per Click" => "Cost Per Click",
    "Campaign" => "Campaign"
  }

  @doc """
  Remaps a list of CSV row maps using GPT field names.

  ## Examples

      iex> remap_headers([%{"campaign_name" => "Jan", "spend" => 1000}])
      [%{"Month" => "Jan", "Ad Spend" => 1000}]
  """
  @spec remap_headers([map()]) :: [map()]
  def remap_headers(rows) when is_list(rows) do
    inverse = Map.new(@mapping, fn {gpt, raw} -> {raw, gpt} end)

    Enum.map(rows, fn row ->
      Enum.reduce(row, %{}, fn {key, value}, acc ->
        Map.put(acc, Map.get(inverse, key, key), value)
      end)
    end)
  end
end
