defmodule DashboardGen.CSVHeaderMapperTest do
  use ExUnit.Case, async: true

  alias DashboardGen.CSVHeaderMapper

  describe "normalize_field/1" do
    test "maps known fields" do
      assert CSVHeaderMapper.normalize_field("cost_per_click") == "Cost Per Click"
      assert CSVHeaderMapper.normalize_field("campaign") == "Campaign"
    end

    test "humanizes unknown fields" do
      assert CSVHeaderMapper.normalize_field("some_field") == "Some Field"
    end
  end

  describe "remap_headers/1" do
    test "remaps keys of each row" do
      rows = [%{"campaign" => "A", "cost_per_click" => 1.23}]

      assert CSVHeaderMapper.remap_headers(rows) == [
               %{"Campaign" => "A", "Cost Per Click" => 1.23}
             ]
    end
  end
end
