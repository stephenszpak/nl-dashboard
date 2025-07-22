defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers
  alias DashboardGen.{Insights, Analytics, Conversations}

  @impl true
  def mount(_params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        # Load dashboard data
        {:ok, assign_dashboard_state(socket)}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("start_chat", _params, socket) do
    {:noreply, push_navigate(socket, to: "/chat")}
  end

  def handle_event("view_insights", _params, socket) do
    {:noreply, push_navigate(socket, to: "/insights")}
  end

  def handle_event("view_agent", _params, socket) do
    {:noreply, push_navigate(socket, to: "/agent")}
  end

  def handle_event("view_uploads", _params, socket) do
    {:noreply, push_navigate(socket, to: "/uploads")}
  end

  def handle_event("view_sentiment", _params, socket) do
    {:noreply, push_navigate(socket, to: "/sentiment")}
  end

  defp assign_dashboard_state(socket) do
    user_id = socket.assigns.current_user.id
    
    # Get recent activity counts
    recent_conversations = Conversations.count_recent_user_conversations(user_id, 7) || 0
    
    assign(socket,
      page_title: "Dashboard",
      recent_conversations: recent_conversations,
      stats: get_dashboard_stats(),
      collapsed: false
    )
  end

  defp get_dashboard_stats do
    %{
      active_agents: 3,
      insights_today: 12,
      competitive_alerts: 5,
      data_sources: 8
    }
  end
end