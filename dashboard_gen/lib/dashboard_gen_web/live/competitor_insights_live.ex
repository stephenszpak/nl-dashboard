defmodule DashboardGenWeb.CompetitorInsightsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.Insights

  @impl true
  def mount(_params, _session, socket) do
    insights = Insights.list_recent_insights_by_company()
    companies = Enum.map(insights, &elem(&1, 0))

    summaries =
      Enum.into(companies, %{}, fn company ->
        case Insights.generate_topic_summary(company) do
          {:ok, summary} -> {company, summary}
          _ -> {company, nil}
        end
      end)

    loading =
      summaries
      |> Enum.filter(fn {_c, s} -> is_nil(s) end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    Enum.each(loading, fn company -> send(self(), {:generate_summary, company}) end)

    {:ok,
     assign(socket,
       page_title: "Competitor Insights",
       collapsed: false,
       insights_by_company: insights,
       companies: companies,
       summaries: summaries,
       loading_summaries: loading,
       company_filter: List.first(companies) || ""
     )}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("filter_company", %{"company" => company}, socket) do
    {:noreply, assign(socket, :company_filter, company)}
  end

  @impl true
  def handle_info({:generate_summary, company}, socket) do
    case Insights.generate_topic_summary(company) do
      {:ok, summary} ->
        socket =
          socket
          |> update(:summaries, &Map.put(&1, company, summary))
          |> update(:loading_summaries, &MapSet.delete(&1, company))

        {:noreply, socket}

      _ ->
        {:noreply, update(socket, :loading_summaries, &MapSet.delete(&1, company))}
    end
  end

  defp snippet(text, len \\ 140)
  defp snippet(nil, _len), do: ""

  defp snippet(text, len) do
    text
    |> String.replace("\n", " ")
    |> String.slice(0, len)
    |> String.trim()
  end

  defp platform_icon(url) do
    cond do
      is_nil(url) -> "chat-bubble-left-right"
      String.contains?(url, "twitter") -> "twitter"
      String.contains?(url, "linkedin") -> "linkedin"
      true -> "chat-bubble-left-right"
    end
  end
end
