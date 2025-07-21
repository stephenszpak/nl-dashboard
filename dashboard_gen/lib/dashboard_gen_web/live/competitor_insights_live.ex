defmodule DashboardGenWeb.CompetitorInsightsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.Insights
  alias DashboardGen.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Get current user from session token for the layout
    user = case Map.get(session, "session_token") do
      token when is_binary(token) ->
        case Accounts.get_valid_session(token) do
          %{user: user} -> user
          _ -> nil
        end
      _ -> nil
    end

    socket = assign(socket, :current_user, user)
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
      String.contains?(url, "youtube") -> "play"
      true -> "chat-bubble-left-right"
    end
  end

  defp format_number(nil), do: "0"
  defp format_number(num) when is_integer(num) and num >= 0 do
    cond do
      num >= 1_000_000 -> "#{Float.round(num / 1_000_000, 1)}M"
      num >= 1_000 -> "#{Float.round(num / 1_000, 1)}K"
      true -> Integer.to_string(num)
    end
  end
  defp format_number(num) when is_binary(num) do
    case Integer.parse(num) do
      {parsed_num, ""} when parsed_num >= 0 -> format_number(parsed_num)
      _ -> "0"
    end
  end
  defp format_number(_), do: "0"
end
