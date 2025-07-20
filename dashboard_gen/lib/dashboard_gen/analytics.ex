defmodule DashboardGen.Analytics do
  @moduledoc """
  Context module for Adobe Analytics data management.
  
  Handles ingestion, querying, and analysis of web analytics data
  from Adobe Analytics for alliancebernstein.com.
  """
  
  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Analytics.{PageView, Event, Visitor, Session}
  alias DashboardGen.CodexClient
  
  @doc """
  Ingest Adobe Analytics data from various sources
  """
  def ingest_analytics_data(data) when is_list(data) do
    Enum.map(data, &process_analytics_record/1)
  end
  
  def ingest_analytics_data(data) when is_map(data) do
    process_analytics_record(data)
  end
  
  @doc """
  Query analytics data for AI analysis
  """
  def query_for_analysis(query_params) do
    %{
      page_views: get_page_views(query_params),
      events: get_events(query_params),
      visitor_metrics: get_visitor_metrics(query_params),
      session_data: get_session_data(query_params)
    }
  end
  
  @doc """
  Analyze user question about analytics data using AI
  """
  def analyze_question(question) do
    # Get relevant analytics data based on the question
    context = build_analytics_context(question)
    
    prompt = """
    You are an Adobe Analytics expert analyzing website performance for AllianceBernstein.com.
    
    User Question: #{question}
    
    Available Analytics Data:
    #{context}
    
    Provide insights about:
    1. Performance trends and patterns
    2. User behavior analysis
    3. Conversion metrics
    4. Areas for improvement
    5. Actionable recommendations
    
    Focus on data-driven insights and specific metrics when available.
    """
    
    case CodexClient.ask(prompt) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Get page view analytics for a specific time period
  """
  def get_page_views(params \\ %{}) do
    query = from(pv in PageView)
    
    query
    |> apply_date_filter(params)
    |> apply_page_filter(params)
    |> apply_geography_filter(params)
    |> order_by([pv], desc: pv.timestamp)
    |> limit(1000)
    |> Repo.all()
  end
  
  @doc """
  Get event tracking data (clicks, interactions, etc.)
  """
  def get_events(params \\ %{}) do
    query = from(e in Event)
    
    query
    |> apply_date_filter(params)
    |> apply_event_filter(params)
    |> apply_geography_filter(params)
    |> order_by([e], desc: e.timestamp)
    |> limit(1000)
    |> Repo.all()
  end
  
  @doc """
  Get visitor metrics and demographics
  """
  def get_visitor_metrics(params \\ %{}) do
    query = from(v in Visitor)
    
    query
    |> apply_date_filter(params)
    |> apply_geography_filter(params)
    |> Repo.all()
  end
  
  @doc """
  Get session data and user journeys
  """
  def get_session_data(params \\ %{}) do
    query = from(s in Session)
    
    query
    |> apply_date_filter(params)
    |> apply_geography_filter(params)
    |> order_by([s], desc: s.start_time)
    |> limit(500)
    |> Repo.all()
  end
  
  @doc """
  Get analytics summary for dashboard display
  """
  def get_analytics_summary(days_back \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days_back)
    cutoff_datetime = DateTime.new!(cutoff_date, ~T[00:00:00], "Etc/UTC")
    
    %{
      total_page_views: count_page_views_since(cutoff_datetime),
      unique_visitors: count_unique_visitors_since(cutoff_datetime),
      top_pages: get_top_pages_since(cutoff_datetime),
      top_events: get_top_events_since(cutoff_datetime),
      geographic_breakdown: get_geographic_breakdown_since(cutoff_datetime),
      conversion_metrics: get_conversion_metrics_since(cutoff_datetime)
    }
  end
  
  ## Private Functions
  
  defp process_analytics_record(%{"type" => "pageview"} = record) do
    changeset = PageView.changeset(%PageView{}, normalize_pageview_data(record))
    Repo.insert(changeset)
  end
  
  defp process_analytics_record(%{"type" => "event"} = record) do
    changeset = Event.changeset(%Event{}, normalize_event_data(record))
    Repo.insert(changeset)
  end
  
  defp process_analytics_record(%{"type" => "visitor"} = record) do
    changeset = Visitor.changeset(%Visitor{}, normalize_visitor_data(record))
    Repo.insert_or_update(changeset)
  end
  
  defp process_analytics_record(%{"type" => "session"} = record) do
    changeset = Session.changeset(%Session{}, normalize_session_data(record))
    Repo.insert(changeset)
  end
  
  defp process_analytics_record(_), do: {:error, :unknown_record_type}
  
  defp normalize_pageview_data(data) do
    %{
      page_url: data["page_url"],
      page_title: data["page_title"],
      visitor_id: data["visitor_id"],
      session_id: data["session_id"],
      timestamp: parse_timestamp(data["timestamp"]),
      referrer: data["referrer"],
      user_agent: data["user_agent"],
      country: data["country"],
      region: data["region"],
      city: data["city"],
      device_type: data["device_type"],
      browser: data["browser"],
      os: data["os"],
      time_on_page: data["time_on_page"]
    }
  end
  
  defp normalize_event_data(data) do
    %{
      event_name: data["event_name"],
      event_category: data["event_category"],
      event_action: data["event_action"],
      event_label: data["event_label"],
      event_value: data["event_value"],
      page_url: data["page_url"],
      visitor_id: data["visitor_id"],
      session_id: data["session_id"],
      timestamp: parse_timestamp(data["timestamp"]),
      country: data["country"],
      region: data["region"],
      device_type: data["device_type"],
      custom_properties: data["custom_properties"] || %{}
    }
  end
  
  defp normalize_visitor_data(data) do
    %{
      visitor_id: data["visitor_id"],
      first_visit: parse_timestamp(data["first_visit"]),
      last_visit: parse_timestamp(data["last_visit"]),
      total_visits: data["total_visits"] || 1,
      total_page_views: data["total_page_views"] || 1,
      country: data["country"],
      region: data["region"],
      city: data["city"],
      device_type: data["device_type"],
      browser: data["browser"],
      os: data["os"],
      acquisition_source: data["acquisition_source"],
      acquisition_medium: data["acquisition_medium"],
      acquisition_campaign: data["acquisition_campaign"]
    }
  end
  
  defp normalize_session_data(data) do
    %{
      session_id: data["session_id"],
      visitor_id: data["visitor_id"],
      start_time: parse_timestamp(data["start_time"]),
      end_time: parse_timestamp(data["end_time"]),
      duration: data["duration"],
      page_views: data["page_views"] || 1,
      events: data["events"] || 0,
      bounce: data["bounce"] || false,
      conversion: data["conversion"] || false,
      conversion_value: data["conversion_value"],
      entry_page: data["entry_page"],
      exit_page: data["exit_page"],
      country: data["country"],
      device_type: data["device_type"]
    }
  end
  
  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_), do: nil
  
  defp apply_date_filter(query, %{"start_date" => start_date, "end_date" => end_date}) do
    apply_date_filter_with_field(query, start_date, end_date)
  end
  defp apply_date_filter(query, %{"days_back" => days}) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
    apply_date_filter_with_cutoff(query, cutoff)
  end
  defp apply_date_filter(query, _), do: query
  
  # Helper to apply date filter based on schema type
  defp apply_date_filter_with_field(%Ecto.Query{from: %{source: {"analytics_page_views", _}}} = query, start_date, end_date) do
    where(query, [r], r.timestamp >= ^start_date and r.timestamp <= ^end_date)
  end
  defp apply_date_filter_with_field(%Ecto.Query{from: %{source: {"analytics_events", _}}} = query, start_date, end_date) do
    where(query, [r], r.timestamp >= ^start_date and r.timestamp <= ^end_date)
  end
  defp apply_date_filter_with_field(%Ecto.Query{from: %{source: {"analytics_visitors", _}}} = query, start_date, end_date) do
    where(query, [r], r.last_visit >= ^start_date and r.last_visit <= ^end_date)
  end
  defp apply_date_filter_with_field(%Ecto.Query{from: %{source: {"analytics_sessions", _}}} = query, start_date, end_date) do
    where(query, [r], r.start_time >= ^start_date and r.start_time <= ^end_date)
  end
  
  defp apply_date_filter_with_cutoff(%Ecto.Query{from: %{source: {"analytics_page_views", _}}} = query, cutoff) do
    where(query, [r], r.timestamp >= ^cutoff)
  end
  defp apply_date_filter_with_cutoff(%Ecto.Query{from: %{source: {"analytics_events", _}}} = query, cutoff) do
    where(query, [r], r.timestamp >= ^cutoff)
  end
  defp apply_date_filter_with_cutoff(%Ecto.Query{from: %{source: {"analytics_visitors", _}}} = query, cutoff) do
    where(query, [r], r.last_visit >= ^cutoff)
  end
  defp apply_date_filter_with_cutoff(%Ecto.Query{from: %{source: {"analytics_sessions", _}}} = query, cutoff) do
    where(query, [r], r.start_time >= ^cutoff)
  end
  
  defp apply_page_filter(query, %{"page_url" => page_url}) do
    where(query, [r], ilike(r.page_url, ^"%#{page_url}%"))
  end
  defp apply_page_filter(query, _), do: query
  
  defp apply_event_filter(query, %{"event_name" => event_name}) do
    where(query, [r], r.event_name == ^event_name)
  end
  defp apply_event_filter(query, %{"event_category" => category}) do
    where(query, [r], r.event_category == ^category)
  end
  defp apply_event_filter(query, _), do: query
  
  defp apply_geography_filter(query, %{"country" => country}) do
    where(query, [r], r.country == ^country)
  end
  defp apply_geography_filter(query, %{"region" => region}) do
    where(query, [r], r.region == ^region)
  end
  defp apply_geography_filter(query, _), do: query
  
  defp build_analytics_context(question) do
    # Extract key terms from the question to fetch relevant data
    query_params = extract_query_params(question)
    
    # Get recent analytics data
    data = query_for_analysis(query_params)
    
    # Build summary context
    """
    Recent Analytics Summary:
    - Page Views: #{length(data.page_views)} records
    - Events: #{length(data.events)} records  
    - Active Visitors: #{length(data.visitor_metrics)} unique visitors
    - Sessions: #{length(data.session_data)} sessions
    
    Top Pages: #{format_top_pages(data.page_views)}
    Top Events: #{format_top_events(data.events)}
    Geographic Distribution: #{format_geography(data.visitor_metrics)}
    """
  end
  
  defp extract_query_params(question) do
    # Simple keyword extraction - could be enhanced with NLP
    params = %{}
    
    # Extract time periods
    params = if String.contains?(String.downcase(question), ["lately", "recent", "this week"]) do
      Map.put(params, "days_back", 7)
    else
      Map.put(params, "days_back", 30)
    end
    
    # Extract page references
    params = cond do
      String.contains?(String.downcase(question), "homepage") ->
        Map.put(params, "page_url", "/")
      String.contains?(String.downcase(question), ["fund", "funds"]) ->
        Map.put(params, "page_url", "fund")
      String.contains?(String.downcase(question), ["search", "searching"]) ->
        Map.put(params, "event_category", "search")
      true -> params
    end
    
    # Extract geography
    params = cond do
      String.contains?(String.downcase(question), "us") or String.contains?(String.downcase(question), "united states") ->
        Map.put(params, "country", "United States")
      true -> params
    end
    
    params
  end
  
  defp format_top_pages(page_views) do
    page_views
    |> Enum.group_by(& &1.page_url)
    |> Enum.map(fn {url, views} -> "#{url} (#{length(views)} views)" end)
    |> Enum.take(5)
    |> Enum.join(", ")
  end
  
  defp format_top_events(events) do
    events
    |> Enum.group_by(& &1.event_name)
    |> Enum.map(fn {event, occurrences} -> "#{event} (#{length(occurrences)})" end)
    |> Enum.take(5)
    |> Enum.join(", ")
  end
  
  defp format_geography(visitors) do
    visitors
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, visits} -> "#{country || "Unknown"} (#{length(visits)})" end)
    |> Enum.take(3)
    |> Enum.join(", ")
  end
  
  # Helper functions for analytics summary
  defp count_page_views_since(date) do
    from(pv in PageView, where: pv.timestamp >= ^date, select: count(pv.id))
    |> Repo.one() || 0
  end
  
  defp count_unique_visitors_since(date) do
    from(pv in PageView, where: pv.timestamp >= ^date, distinct: true, select: count(pv.visitor_id, :distinct))
    |> Repo.one() || 0
  end
  
  defp get_top_pages_since(date) do
    from(pv in PageView,
      where: pv.timestamp >= ^date,
      group_by: pv.page_url,
      select: {pv.page_url, count(pv.id)},
      order_by: [desc: count(pv.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn {page_url, count} -> %{page: page_url, views: count} end)
  end
  
  defp get_top_events_since(date) do
    from(e in Event,
      where: e.timestamp >= ^date,
      group_by: e.event_name,
      select: {e.event_name, count(e.id)},
      order_by: [desc: count(e.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn {event_name, count} -> %{event: event_name, count: count} end)
  end
  
  defp get_geographic_breakdown_since(date) do
    from(v in Visitor,
      where: v.last_visit >= ^date,
      group_by: v.country,
      select: {v.country, count(v.id)},
      order_by: [desc: count(v.id)],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(fn {country, count} -> %{country: country || "Unknown", visitors: count} end)
  end
  
  defp get_conversion_metrics_since(date) do
    from(s in Session,
      where: s.start_time >= ^date,
      select: %{
        total_sessions: count(s.id),
        conversions: count(s.id, :distinct),
        avg_duration: avg(s.duration),
        bounce_rate: avg(fragment("CASE WHEN ? THEN 1.0 ELSE 0.0 END", s.bounce))
      }
    )
    |> Repo.one() || %{total_sessions: 0, conversions: 0, avg_duration: 0, bounce_rate: 0}
  end
end