defmodule DashboardGenWeb.AnalyticsController do
  @moduledoc """
  API endpoints for ingesting Adobe Analytics data.
  
  Provides endpoints to receive analytics data from Adobe Analytics
  via webhook, batch upload, or real-time streaming.
  """
  
  use DashboardGenWeb, :controller
  
  alias DashboardGen.Analytics
  
  @doc """
  Webhook endpoint for Adobe Analytics real-time data
  """
  def webhook(conn, params) do
    case validate_webhook_signature(conn, params) do
      :ok ->
        case Analytics.ingest_analytics_data(params["data"]) do
          results when is_list(results) ->
            successful = Enum.count(results, fn {status, _} -> status == :ok end)
            
            conn
            |> put_status(:ok)
            |> json(%{
              status: "success", 
              message: "Processed #{successful} records",
              total_received: length(results),
              successful: successful
            })
          
          {:ok, _result} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "success", message: "Data ingested successfully"})
          
          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{status: "error", message: "Failed to ingest data: #{inspect(reason)}"})
        end
      
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Webhook validation failed: #{reason}"})
    end
  end
  
  @doc """
  Batch upload endpoint for historical analytics data
  """
  def batch_upload(conn, %{"file" => upload}) do
    with {:ok, content} <- File.read(upload.path),
         {:ok, data} <- Jason.decode(content),
         results <- Analytics.ingest_analytics_data(data) do
      
      successful = Enum.count(results, fn {status, _} -> status == :ok end)
      failed = length(results) - successful
      
      conn
      |> put_status(:ok)
      |> json(%{
        status: "success",
        message: "Batch upload completed",
        total_records: length(results),
        successful: successful,
        failed: failed
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Batch upload failed: #{inspect(reason)}"})
    end
  end
  
  @doc """
  Manual data entry endpoint for testing
  """
  def manual_entry(conn, params) do
    case Analytics.ingest_analytics_data(params) do
      {:ok, _result} ->
        conn
        |> put_status(:created)
        |> json(%{status: "success", message: "Analytics data created"})
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to create data: #{inspect(reason)}"})
    end
  end
  
  @doc """
  Get analytics summary for dashboard display
  """
  def summary(conn, params) do
    days_back = Map.get(params, "days", "30") |> String.to_integer()
    summary = Analytics.get_analytics_summary(days_back)
    
    conn
    |> put_status(:ok)
    |> json(%{status: "success", data: summary})
  end
  
  @doc """
  Test endpoint to generate sample analytics data
  """
  def generate_sample_data(conn, _params) do
    sample_data = generate_sample_analytics_data()
    
    case Analytics.ingest_analytics_data(sample_data) do
      results when is_list(results) ->
        successful = Enum.count(results, fn {status, _} -> status == :ok end)
        
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          message: "Generated #{successful} sample records",
          data_types: ["page_views", "events", "visitors", "sessions"]
        })
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to generate sample data: #{inspect(reason)}"})
    end
  end
  
  @doc """
  Generate realistic AllianceBernstein.com analytics data
  """
  def generate_realistic_data(conn, params) do
    alias DashboardGen.Analytics.MockData
    
    days_back = Map.get(params, "days", "7") |> String.to_integer() |> min(30)
    records_per_day = Map.get(params, "records_per_day", "100") |> String.to_integer() |> min(500)
    
    case MockData.generate_realistic_data(days_back, records_per_day) do
      results when is_list(results) ->
        successful = Enum.count(results, fn {status, _} -> status == :ok end)
        total = length(results)
        
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          message: "Generated realistic AllianceBernstein.com analytics data",
          total_records: total,
          successful: successful,
          failed: total - successful,
          days_generated: days_back,
          records_per_day: records_per_day
        })
      
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to generate realistic data: #{inspect(reason)}"})
    end
  end
  
  ## Private Functions
  
  defp validate_webhook_signature(conn, _params) do
    # In production, validate Adobe Analytics webhook signature
    # For now, check for a simple API key
    case get_req_header(conn, "x-api-key") do
      [api_key] when api_key != "" ->
        expected_key = System.get_env("ANALYTICS_API_KEY") || "dev_analytics_key"
        if api_key == expected_key, do: :ok, else: {:error, "Invalid API key"}
      
      _ ->
        {:error, "Missing API key"}
    end
  end
  
  defp generate_sample_analytics_data do
    now = DateTime.utc_now()
    visitor_id = "visitor_#{:rand.uniform(10000)}"
    session_id = "session_#{:rand.uniform(10000)}"
    
    pages = [
      "/", "/funds", "/funds/search", "/about", "/insights", 
      "/contact", "/funds/equity", "/funds/fixed-income"
    ]
    
    countries = ["United States", "Canada", "United Kingdom", "Germany", "Japan"]
    devices = ["desktop", "mobile", "tablet"]
    
    [
      # Page views
      %{
        "type" => "pageview",
        "page_url" => Enum.random(pages),
        "page_title" => "AllianceBernstein - Investment Management",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.add(now, -:rand.uniform(86400), :second) |> DateTime.to_iso8601(),
        "country" => Enum.random(countries),
        "device_type" => Enum.random(devices),
        "time_on_page" => :rand.uniform(300)
      },
      
      # Events
      %{
        "type" => "event",
        "event_name" => "fund_search",
        "event_category" => "search",
        "event_action" => "click",
        "event_label" => "equity_funds",
        "page_url" => "/funds/search",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.add(now, -:rand.uniform(86400), :second) |> DateTime.to_iso8601(),
        "country" => Enum.random(countries),
        "device_type" => Enum.random(devices)
      },
      
      # Visitor
      %{
        "type" => "visitor",
        "visitor_id" => visitor_id,
        "first_visit" => DateTime.add(now, -:rand.uniform(86400), :second) |> DateTime.to_iso8601(),
        "last_visit" => now |> DateTime.to_iso8601(),
        "total_visits" => :rand.uniform(5),
        "total_page_views" => :rand.uniform(20),
        "country" => Enum.random(countries),
        "device_type" => Enum.random(devices),
        "acquisition_source" => Enum.random(["google", "direct", "linkedin", "twitter"])
      },
      
      # Session
      %{
        "type" => "session",
        "session_id" => session_id,
        "visitor_id" => visitor_id,
        "start_time" => DateTime.add(now, -:rand.uniform(3600), :second) |> DateTime.to_iso8601(),
        "end_time" => now |> DateTime.to_iso8601(),
        "duration" => :rand.uniform(1800),
        "page_views" => :rand.uniform(10),
        "events" => :rand.uniform(5),
        "entry_page" => Enum.random(pages),
        "country" => Enum.random(countries),
        "device_type" => Enum.random(devices),
        "conversion" => :rand.uniform(10) > 8 # 20% conversion rate
      }
    ]
  end
end