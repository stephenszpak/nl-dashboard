defmodule DashboardGen.UploadsTest do
  use ExUnit.Case, async: true
  alias DashboardGen.Uploads

  test "parse_csv normalizes flexible headers" do
    csv = [
      "date,cmp001,campaign name,cpc,impressions,clicks,conversions,google_ads",
      "2023-01-01,123,My Campaign,0.5,1000,10,2,google"
    ] |> Enum.join("\n")
    path = Path.join(System.tmp_dir!(), "upload_test.csv")
    File.write!(path, csv)

    assert {:ok, %{headers: headers, rows: [row]}} = Uploads.parse_csv(path)

    assert headers == %{
             "date" => "date",
             "campaign_id" => "cmp001",
             "campaign_name" => "campaign name",
             "cost_per_click" => "cpc",
             "impressions" => "impressions",
             "clicks" => "clicks",
             "conversions" => "conversions",
             "source" => "google_ads"
           }

    assert row == %{
             "date" => "2023-01-01",
             "campaign_id" => 123,
             "campaign_name" => "My Campaign",
             "cost_per_click" => 0.5,
             "impressions" => 1000,
             "clicks" => 10,
             "conversions" => 2,
             "source" => "google"
           }
  end

  test "parse_csv handles BOM in headers" do
    bom = <<239, 187, 191>>
    csv = [
      bom <> "date,campaign_id,campaign_name,cost_per_click,impressions,clicks,conversions,source",
      "2023-01-01,1,Campaign,0.5,100,10,1,google"
    ] |> Enum.join("\n")
    path = Path.join(System.tmp_dir!(), "upload_bom.csv")
    File.write!(path, csv)

    assert {:ok, %{headers: headers, rows: [_]}} = Uploads.parse_csv(path)
    assert Map.has_key?(headers, "date")
  end

  test "parse_csv errors when headers are missing and first row is data" do
    csv = [
      "2023-01-01,1,Campaign,0.5,100,10,1,google",
      "2023-01-02,2,Another,0.4,200,20,3,bing"
    ] |> Enum.join("\n")

    path = Path.join(System.tmp_dir!(), "upload_no_header.csv")
    File.write!(path, csv)

    assert {:error, msg} = Uploads.parse_csv(path)
    assert msg =~ "missing header row"
  end

  test "parse_csv errors when required header missing" do
    csv = [
      "date,campaign name,cpc,impressions,conversions,google_ads",
      "2023-01-01,My Campaign,0.5,1000,2,google"
    ] |> Enum.join("\n")
    path = Path.join(System.tmp_dir!(), "upload_missing.csv")
    File.write!(path, csv)

    assert {:error, msg} = Uploads.parse_csv(path)
    assert msg == "Invalid CSV: missing required column 'campaign_id'" or
             msg == "Invalid CSV: missing required column 'clicks'" or msg =~ "missing required column"
  end
end
