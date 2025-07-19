defmodule DashboardGenWeb.CompetitorInsightsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.Insights

  @impl true
  def mount(_params, _session, socket) do
    insights = Insights.list_recent_insights_by_company()
    companies = Enum.map(insights, &elem(&1, 0))

    {:ok,
     assign(socket,
       page_title: "Competitor Insights",
       collapsed: false,
       insights_by_company: insights,
       companies: companies,
       company_filter: ""
     )}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("filter_company", %{"company" => company}, socket) do
    {:noreply, assign(socket, :company_filter, company)}
  end
end
