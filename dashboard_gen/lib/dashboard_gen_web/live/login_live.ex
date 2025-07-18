defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  alias DashboardGen.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, collapsed: false, page_title: "Login")}
  end

  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:noreply,
         socket
         |> DashboardGenWeb.LiveHelpers.maybe_put_session(:user_id, user.id)
         |> Phoenix.LiveView.push_navigate(to: "/dashboard")}

      :error ->
        {:noreply, assign(socket, error: "Invalid email or password")}
    end
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end
end
