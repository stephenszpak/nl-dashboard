defmodule DashboardGenWeb.AIInsightsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers

  alias DashboardGen.AI

  @impl true
  def mount(_params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} -> {:ok, redirect_socket}
      {:ok, socket} ->
        companies = available_companies()
        company = List.first(companies) || "AllianceBernstein"

        {:ok,
         socket
         |> assign(
           page_title: "AI Insights",
           collapsed: false,
           companies: companies,
           selected_company: company,
           timeframe: "30d",
           tab: "snapshot",
           snapshot: AI.latest_snapshot_or_nil(company),
           events: AI.list_events_or_empty(company, days_back: 30, limit: 50)
         )}
    end
  end

  @impl true
  def handle_event("change_company", %{"company" => company}, socket) do
    days = tf_days(socket.assigns.timeframe)
    {:noreply,
     socket
     |> assign(selected_company: company)
     |> load_data(company, days)}
  end

  def handle_event("change_timeframe", %{"timeframe" => tf}, socket) do
    company = socket.assigns.selected_company
    days = tf_days(tf)
    {:noreply,
     socket
     |> assign(timeframe: tf)
     |> load_data(company, days)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: tab)}
  end

  def handle_event("generate_recos", _params, socket) do
    company = socket.assigns.selected_company
    days = tf_days(socket.assigns.timeframe)
    Task.start(fn -> DashboardGen.Insights.AIScout.generate_recommendations(company, days) end)
    {:noreply, put_flash(socket, :info, "Generating recommendations...")}
  end

  defp load_data(socket, company, days) do
    assign(socket,
      snapshot: AI.latest_snapshot_or_nil(company),
      events: AI.list_events_or_empty(company, days_back: days, limit: 100)
    )
  end

  defp available_companies do
    (Application.get_env(:dashboard_gen, :data_collectors)[:companies] || [])
  end

  defp tf_days("7d"), do: 7
  defp tf_days("30d"), do: 30
  defp tf_days("90d"), do: 90
  defp tf_days(_), do: 30
end
