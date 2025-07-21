defmodule DashboardGenWeb.OnboardingLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  alias DashboardGen.Accounts

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

    if user do
      {:ok, assign(socket, user: user, current_user: user, collapsed: false, page_title: "Onboarding")}
    else
      {:ok, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end

  def handle_event("run_query", _params, socket) do
    Accounts.mark_onboarded(socket.assigns.user)
    {:noreply, Phoenix.LiveView.push_navigate(socket, to: "/dashboard")}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end
end
