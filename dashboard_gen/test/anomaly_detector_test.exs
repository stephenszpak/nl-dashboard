defmodule DashboardGen.AnomalyDetectorTest do
  use ExUnit.Case, async: true

  alias DashboardGen.AnomalyDetector

  test "detect_anomalies finds significant changes" do
    headers = %{"date" => "Date", "source" => "Source", "cost_per_click" => "cpc", "clicks" => "clicks", "conversions" => "conversions"}

    rows = [
      %{"date" => "2024-01-01", "source" => "facebook", "cost_per_click" => 1.0, "clicks" => 100, "conversions" => 10},
      %{"date" => "2024-01-02", "source" => "facebook", "cost_per_click" => 1.1, "clicks" => 100, "conversions" => 10},
      %{"date" => "2024-01-03", "source" => "facebook", "cost_per_click" => 1.5, "clicks" => 80, "conversions" => 5}
    ]

    assert {:ok, anomalies} = AnomalyDetector.detect_anomalies(headers, rows)
    assert length(anomalies) == 2

    cpc = Enum.find(anomalies, &(&1.metric == "cpc"))
    assert cpc.date == "2024-01-03"
    assert cpc.direction == :up
    assert_in_delta cpc.percent_change, 36.0, 1.0
    assert cpc.source == "facebook"

    conv = Enum.find(anomalies, &(&1.metric == "conversions"))
    assert conv.direction == :down
    assert_in_delta conv.percent_change, 50.0, 1.0
  end
end

