defmodule DashboardGenWeb.SentimentLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers
  alias DashboardGen.Sentiment
  alias DashboardGen.Sentiment.{SentimentAnalyzer, SentimentAggregator}

  @impl true
  def mount(_params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        {:ok, assign_initial_state(socket)}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("load_company_data", %{"company" => company}, socket) do
    {:noreply, 
     socket
     |> assign(selected_company: company, loading: true)
     |> load_sentiment_data(company)}
  end

  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    days = timeframe_to_days(timeframe)
    company = socket.assigns.selected_company
    
    {:noreply,
     socket
     |> assign(timeframe: timeframe, loading: true)
     |> load_sentiment_data(company, days)}
  end

  def handle_event("refresh_data", _params, socket) do
    company = socket.assigns.selected_company
    days = timeframe_to_days(socket.assigns.timeframe)
    
    {:noreply,
     socket
     |> assign(loading: true)
     |> load_sentiment_data(company, days)}
  end

  def handle_event("toggle_comparison", _params, socket) do
    {:noreply, update(socket, :show_comparison, &(!&1))}
  end

  def handle_event("add_comparison_company", %{"company" => company}, socket) do
    current_companies = socket.assigns.comparison_companies
    
    if company not in current_companies and length(current_companies) < 4 do
      updated_companies = [company | current_companies]
      comparison_data = load_comparison_data(updated_companies, timeframe_to_days(socket.assigns.timeframe))
      
      {:noreply,
       assign(socket,
         comparison_companies: updated_companies,
         comparison_data: comparison_data
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_comparison_company", %{"company" => company}, socket) do
    updated_companies = List.delete(socket.assigns.comparison_companies, company)
    comparison_data = if length(updated_companies) > 0 do
      load_comparison_data(updated_companies, timeframe_to_days(socket.assigns.timeframe))
    else
      []
    end
    
    {:noreply,
     assign(socket,
       comparison_companies: updated_companies,
       comparison_data: comparison_data
     )}
  end

  def handle_event("test_analysis", %{"content" => content}, socket) when content != "" do
    company = socket.assigns.selected_company
    
    # Start async analysis
    send(self(), {:analyze_test_content, content, company})
    
    {:noreply, assign(socket, test_analysis_loading: true)}
  end

  def handle_event("test_analysis", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:analyze_test_content, content, company}, socket) do
    case SentimentAnalyzer.analyze_text(content, company: company) do
      {:ok, analysis} ->
        {:noreply,
         assign(socket,
           test_analysis_result: analysis,
           test_analysis_loading: false
         )}
      {:error, reason} ->
        {:noreply,
         socket
         |> assign(test_analysis_loading: false)
         |> put_flash(:error, "Analysis failed: #{reason}")}
    end
  end

  def handle_info({:sentiment_data_loaded, company, data}, socket) do
    {:noreply,
     assign(socket,
       loading: false,
       sentiment_summary: data.summary,
       trend_data: data.trend,
       trending_topics: data.topics,
       alerts: data.alerts,
       insights: data.insights
     )}
  end

  ## Data Loading Functions
  
  defp assign_initial_state(socket) do
    assign(socket,
      page_title: "Sentiment Analysis",
      collapsed: false,
      loading: false,
      selected_company: "BlackRock",
      timeframe: "7d",
      sentiment_summary: nil,
      trend_data: [],
      trending_topics: [],
      alerts: [],
      insights: nil,
      show_comparison: false,
      comparison_companies: [],
      comparison_data: [],
      test_analysis_result: nil,
      test_analysis_loading: false,
      available_companies: get_available_companies()
    )
  end

  defp load_sentiment_data(socket, company, days \\ 7) do
    # Load data asynchronously to avoid blocking UI
    Task.start(fn ->
      data = %{
        summary: Sentiment.get_sentiment_summary(company, days),
        trend: Sentiment.get_daily_sentiment_trend(company, days),
        topics: Sentiment.get_trending_topics(company, days),
        alerts: Sentiment.detect_sentiment_alerts(company),
        insights: case Sentiment.generate_sentiment_insights(company, days) do
          {:ok, insights} -> insights
          _ -> nil
        end
      }
      
      send(self(), {:sentiment_data_loaded, company, data})
    end)
    
    socket
  end

  defp load_comparison_data(companies, days) do
    Sentiment.compare_company_sentiment(companies, days)
  end

  defp timeframe_to_days("1d"), do: 1
  defp timeframe_to_days("7d"), do: 7
  defp timeframe_to_days("30d"), do: 30
  defp timeframe_to_days("90d"), do: 90
  defp timeframe_to_days(_), do: 7

  defp get_available_companies do
    # This would normally come from your data
    ["BlackRock", "Vanguard", "State Street", "Fidelity", "Goldman Sachs", "JPMorgan Chase", "Morgan Stanley"]
  end

  ## Helper Functions

  defp sentiment_color(score) when score > 0.2, do: "text-green-600"
  defp sentiment_color(score) when score < -0.2, do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"

  defp sentiment_bg_color(score) when score > 0.2, do: "bg-green-100"
  defp sentiment_bg_color(score) when score < -0.2, do: "bg-red-100"
  defp sentiment_bg_color(_), do: "bg-gray-100"

  defp alert_severity_class(:high), do: "border-red-500 bg-red-50"
  defp alert_severity_class(:medium), do: "border-orange-500 bg-orange-50"
  defp alert_severity_class(_), do: "border-yellow-500 bg-yellow-50"

  defp alert_severity_text_class(:high), do: "text-red-800"
  defp alert_severity_text_class(:medium), do: "text-orange-800"
  defp alert_severity_text_class(_), do: "text-yellow-800"

  defp format_percentage(value) when is_float(value), do: "#{Float.round(value, 1)}%"
  defp format_percentage(value) when is_integer(value), do: "#{value}%"
  defp format_percentage(_), do: "0%"

  defp format_sentiment_score(score) when is_float(score), do: Float.round(score, 3)
  defp format_sentiment_score(score) when is_integer(score), do: score / 1.0
  defp format_sentiment_score(_), do: 0.0

  defp chart_data_for_trend(trend_data) do
    trend_data
    |> Enum.map(fn day ->
      %{
        date: day.date,
        sentiment: day.avg_sentiment || 0,
        mentions: day.total_mentions || 0
      }
    end)
    |> Jason.encode!()
  end
end