defmodule DashboardGenWeb.OnboardingLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  alias DashboardGen.Accounts

  def mount(_params, session, socket) do
    user = session["user_id"] && Accounts.get_user(session["user_id"])

    if user do
      {:ok, assign(socket, user: user, collapsed: false)}
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
