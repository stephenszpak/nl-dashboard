defmodule DashboardGen.Analytics.MockData do
  @moduledoc """
  Generates realistic mock analytics data for AllianceBernstein.com
  
  Creates sample data that mimics real user behavior patterns
  for testing and demonstration purposes.
  """
  
  alias DashboardGen.Analytics
  
  @doc """
  Generate comprehensive mock analytics data
  """
  def generate_realistic_data(days_back \\ 30, records_per_day \\ 50) do
    # Generate data for the past N days
    date_range = Date.range(Date.add(Date.utc_today(), -days_back), Date.utc_today())
    
    all_data = 
      date_range
      |> Enum.flat_map(fn date ->
        generate_day_data(date, records_per_day)
      end)
    
    # Ingest all the data
    Analytics.ingest_analytics_data(all_data)
  end
  
  @doc """
  Generate sample data for a specific day
  """
  def generate_day_data(date, num_records \\ 50) do
    # Create multiple sessions throughout the day
    num_sessions = div(num_records, 10)
    
    1..num_sessions
    |> Enum.flat_map(fn session_num ->
      generate_session_data(date, session_num)
    end)
  end
  
  @doc """
  Generate a realistic user session with multiple page views and events
  """
  def generate_session_data(date, session_num \\ 1) do
    # Create unique IDs
    visitor_id = "visitor_#{Date.to_string(date)}_#{session_num}_#{:rand.uniform(1000)}"
    session_id = "session_#{Date.to_string(date)}_#{session_num}_#{:rand.uniform(1000)}"
    
    # Random session timing
    hour = :rand.uniform(24) - 1
    minute = :rand.uniform(60) - 1
    session_start = DateTime.new!(date, Time.new!(hour, minute, 0))
    
    # Geographic and device data
    geo_device = random_geo_device()
    
    # User journey through the site
    journey = generate_user_journey()
    
    # Generate session record
    session_duration = length(journey) * (:rand.uniform(120) + 30) # 30-150 seconds per page
    session_end = DateTime.add(session_start, session_duration, :second)
    
    session_data = %{
      "type" => "session",
      "session_id" => session_id,
      "visitor_id" => visitor_id,
      "start_time" => DateTime.to_iso8601(session_start),
      "end_time" => DateTime.to_iso8601(session_end),
      "duration" => session_duration,
      "page_views" => length(journey),
      "events" => count_events_in_journey(journey),
      "entry_page" => List.first(journey)["page_url"],
      "exit_page" => List.last(journey)["page_url"],
      "country" => geo_device.country,
      "device_type" => geo_device.device_type,
      "conversion" => has_conversion?(journey),
      "bounce" => length(journey) == 1
    }
    
    # Generate visitor record
    visitor_data = %{
      "type" => "visitor",
      "visitor_id" => visitor_id,
      "first_visit" => DateTime.to_iso8601(session_start),
      "last_visit" => DateTime.to_iso8601(session_end),
      "total_visits" => :rand.uniform(5),
      "total_page_views" => length(journey),
      "country" => geo_device.country,
      "device_type" => geo_device.device_type,
      "acquisition_source" => random_acquisition_source(),
      "visitor_type" => random_visitor_type()
    }
    
    # Generate page views and events
    journey_data = 
      journey
      |> Enum.with_index()
      |> Enum.flat_map(fn {page_info, index} ->
        page_timestamp = DateTime.add(session_start, index * 60, :second)
        
        page_view = create_page_view(page_info, visitor_id, session_id, page_timestamp, geo_device)
        events = create_page_events(page_info, visitor_id, session_id, page_timestamp, geo_device)
        
        [page_view | events]
      end)
    
    [session_data, visitor_data | journey_data]
  end
  
  ## Private Functions
  
  defp generate_user_journey do
    # Common user paths through AllianceBernstein.com
    entry_pages = [
      %{"page_url" => "/", "page_title" => "AllianceBernstein - Global Investment Management"},
      %{"page_url" => "/funds", "page_title" => "Investment Funds - AllianceBernstein"},
      %{"page_url" => "/insights", "page_title" => "Market Insights - AllianceBernstein"},
      %{"page_url" => "/about", "page_title" => "About AllianceBernstein"}
    ]
    
    # Start with an entry page
    journey = [Enum.random(entry_pages)]
    
    # Add 1-5 additional pages based on user behavior
    num_additional_pages = :rand.uniform(5)
    
    1..num_additional_pages
    |> Enum.reduce(journey, fn _, acc ->
      current_page = List.last(acc)
      next_page = get_likely_next_page(current_page["page_url"])
      acc ++ [next_page]
    end)
  end
  
  defp get_likely_next_page(current_url) do
    case current_url do
      "/" ->
        Enum.random([
          %{"page_url" => "/funds", "page_title" => "Investment Funds - AllianceBernstein"},
          %{"page_url" => "/insights", "page_title" => "Market Insights - AllianceBernstein"},
          %{"page_url" => "/about", "page_title" => "About AllianceBernstein"},
          %{"page_url" => "/funds/search", "page_title" => "Fund Search - AllianceBernstein"}
        ])
      
      "/funds" ->
        Enum.random([
          %{"page_url" => "/funds/search", "page_title" => "Fund Search - AllianceBernstein"},
          %{"page_url" => "/funds/equity", "page_title" => "Equity Funds - AllianceBernstein"},
          %{"page_url" => "/funds/fixed-income", "page_title" => "Fixed Income Funds - AllianceBernstein"},
          %{"page_url" => "/funds/alternatives", "page_title" => "Alternative Investments - AllianceBernstein"}
        ])
      
      "/funds/search" ->
        Enum.random([
          %{"page_url" => "/funds/equity/us-growth", "page_title" => "US Growth Fund - AllianceBernstein"},
          %{"page_url" => "/funds/fixed-income/global-bond", "page_title" => "Global Bond Fund - AllianceBernstein"},
          %{"page_url" => "/contact", "page_title" => "Contact Us - AllianceBernstein"}
        ])
      
      "/insights" ->
        Enum.random([
          %{"page_url" => "/insights/market-outlook", "page_title" => "Market Outlook - AllianceBernstein"},
          %{"page_url" => "/insights/investment-themes", "page_title" => "Investment Themes - AllianceBernstein"},
          %{"page_url" => "/funds", "page_title" => "Investment Funds - AllianceBernstein"}
        ])
      
      _ ->
        Enum.random([
          %{"page_url" => "/contact", "page_title" => "Contact Us - AllianceBernstein"},
          %{"page_url" => "/", "page_title" => "AllianceBernstein - Global Investment Management"}
        ])
    end
  end
  
  defp random_geo_device do
    countries = [
      %{country: "United States", weight: 45},
      %{country: "United Kingdom", weight: 15},
      %{country: "Canada", weight: 10},
      %{country: "Germany", weight: 8},
      %{country: "Japan", weight: 7},
      %{country: "Australia", weight: 5},
      %{country: "Switzerland", weight: 4},
      %{country: "Singapore", weight: 3},
      %{country: "Netherlands", weight: 2},
      %{country: "France", weight: 1}
    ]
    
    devices = [
      %{type: "desktop", weight: 55},
      %{type: "mobile", weight: 35},
      %{type: "tablet", weight: 10}
    ]
    
    %{
      country: weighted_random(countries),
      device_type: weighted_random(devices),
      region: random_region(),
      city: random_city()
    }
  end
  
  defp weighted_random(items) do
    total_weight = Enum.sum(Enum.map(items, & &1.weight))
    random_num = :rand.uniform(total_weight)
    
    items
    |> Enum.reduce_while(0, fn item, acc ->
      new_acc = acc + item.weight
      if random_num <= new_acc do
        {:halt, Map.get(item, :country) || Map.get(item, :type)}
      else
        {:cont, new_acc}
      end
    end)
  end
  
  defp random_region, do: Enum.random(["NY", "CA", "TX", "FL", "London", "Ontario", "Berlin"])
  defp random_city, do: Enum.random(["New York", "Los Angeles", "Chicago", "London", "Toronto", "Berlin"])
  
  defp random_acquisition_source do
    sources = [
      %{source: "google", weight: 40},
      %{source: "direct", weight: 25},
      %{source: "linkedin", weight: 15},
      %{source: "bloomberg", weight: 10},
      %{source: "twitter", weight: 5},
      %{source: "email", weight: 5}
    ]
    
    weighted_random(sources)
  end
  
  defp random_visitor_type do
    types = [
      %{type: "returning", weight: 60},
      %{type: "new", weight: 35},
      %{type: "loyal", weight: 5}
    ]
    
    weighted_random(types)
  end
  
  defp count_events_in_journey(journey) do
    # Estimate events per page based on page type
    journey
    |> Enum.map(fn page ->
      url = page["page_url"]
      cond do
        url in ["/funds/search", "/contact"] -> :rand.uniform(5) + 2 # 2-7 events
        String.contains?(url, "/funds/") -> :rand.uniform(3) + 1 # 1-4 events
        url == "/" -> :rand.uniform(4) + 1 # 1-5 events
        true -> :rand.uniform(2) + 1 # 1-3 events
      end
    end)
    |> Enum.sum()
  end
  
  defp has_conversion?(journey) do
    # Check if user reached a conversion page
    conversion_pages = ["/contact", "/funds/search"]
    
    Enum.any?(journey, fn page ->
      page["page_url"] in conversion_pages
    end) and :rand.uniform(10) > 7 # 30% conversion rate for users who reach conversion pages
  end
  
  defp create_page_view(page_info, visitor_id, session_id, timestamp, geo_device) do
    %{
      "type" => "pageview",
      "page_url" => page_info["page_url"],
      "page_title" => page_info["page_title"],
      "visitor_id" => visitor_id,
      "session_id" => session_id,
      "timestamp" => DateTime.to_iso8601(timestamp),
      "country" => geo_device.country,
      "region" => geo_device.region,
      "city" => geo_device.city,
      "device_type" => geo_device.device_type,
      "browser" => random_browser(geo_device.device_type),
      "time_on_page" => :rand.uniform(180) + 30, # 30-210 seconds
      "scroll_depth" => :rand.uniform(100) / 100.0 # 0-100%
    }
  end
  
  defp create_page_events(page_info, visitor_id, session_id, timestamp, geo_device) do
    url = page_info["page_url"]
    
    cond do
      url == "/" -> 
        create_homepage_events(visitor_id, session_id, timestamp, geo_device)
      url == "/funds/search" ->
        create_search_events(visitor_id, session_id, timestamp, geo_device)
      url == "/contact" ->
        create_contact_events(visitor_id, session_id, timestamp, geo_device)
      String.contains?(url, "/funds/") ->
        create_fund_page_events(page_info["page_url"], visitor_id, session_id, timestamp, geo_device)
      true ->
        create_generic_events(page_info["page_url"], visitor_id, session_id, timestamp, geo_device)
    end
  end
  
  defp create_homepage_events(visitor_id, session_id, timestamp, geo_device) do
    events = [
      %{
        "type" => "event",
        "event_name" => "hero_banner_view",
        "event_category" => "engagement",
        "event_action" => "view",
        "event_label" => "main_hero",
        "page_url" => "/",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 5, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }
    ]
    
    # Randomly add more events
    if :rand.uniform(10) > 6 do
      events ++ [%{
        "type" => "event",
        "event_name" => "fund_search_click",
        "event_category" => "navigation",
        "event_action" => "click",
        "event_label" => "header_search",
        "page_url" => "/",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 15, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }]
    else
      events
    end
  end
  
  defp create_search_events(visitor_id, session_id, timestamp, geo_device) do
    search_terms = ["equity", "growth", "income", "ESG", "technology", "healthcare"]
    
    [
      %{
        "type" => "event",
        "event_name" => "fund_search_performed",
        "event_category" => "search",
        "event_action" => "search",
        "event_label" => Enum.random(search_terms),
        "page_url" => "/funds/search",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 10, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      },
      %{
        "type" => "event",
        "event_name" => "fund_filter_applied",
        "event_category" => "interaction",
        "event_action" => "filter",
        "event_label" => "asset_class",
        "page_url" => "/funds/search",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 25, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }
    ]
  end
  
  defp create_contact_events(visitor_id, session_id, timestamp, geo_device) do
    [
      %{
        "type" => "event",
        "event_name" => "contact_form_start",
        "event_category" => "conversion",
        "event_action" => "form_start",
        "event_label" => "contact_form",
        "page_url" => "/contact",
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 20, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }
    ]
  end
  
  defp create_fund_page_events(page_url, visitor_id, session_id, timestamp, geo_device) do
    [
      %{
        "type" => "event",
        "event_name" => "fund_factsheet_download",
        "event_category" => "download",
        "event_action" => "click",
        "event_label" => "pdf_factsheet",
        "page_url" => page_url,
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 30, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }
    ]
  end
  
  defp create_generic_events(page_url, visitor_id, session_id, timestamp, geo_device) do
    [
      %{
        "type" => "event",
        "event_name" => "page_scroll",
        "event_category" => "engagement",
        "event_action" => "scroll",
        "event_label" => "50_percent",
        "page_url" => page_url,
        "visitor_id" => visitor_id,
        "session_id" => session_id,
        "timestamp" => DateTime.to_iso8601(DateTime.add(timestamp, 45, :second)),
        "country" => geo_device.country,
        "device_type" => geo_device.device_type
      }
    ]
  end
  
  defp random_browser(device_type) do
    case device_type do
      "mobile" -> Enum.random(["Chrome Mobile", "Safari", "Samsung Internet", "Firefox Mobile"])
      "tablet" -> Enum.random(["Safari", "Chrome", "Samsung Internet"])
      _ -> Enum.random(["Chrome", "Safari", "Firefox", "Edge"])
    end
  end
end