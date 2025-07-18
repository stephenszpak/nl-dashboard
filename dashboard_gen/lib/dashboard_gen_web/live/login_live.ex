defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :root}
  use DashboardGenWeb, :html
  alias DashboardGen.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil)}
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
end
