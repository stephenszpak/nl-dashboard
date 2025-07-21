defmodule DashboardGenWeb.LoginLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :auth}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  alias DashboardGen.Accounts

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, page_title: "Login")}
  end

  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
<<<<<<< HEAD
        case Accounts.create_session(user.id) do
          {:ok, session} ->
            {:noreply,
             socket
             |> DashboardGenWeb.LiveHelpers.maybe_put_session(:session_token, session.token)
             |> Phoenix.LiveView.push_navigate(to: "/dashboard")}
          {:error, _} ->
            {:noreply, assign(socket, error: "Unable to create session. Please try again.")}
        end
=======
        {:noreply,
         socket
         |> DashboardGenWeb.LiveHelpers.maybe_put_session(:user_id, user.id)
         |> Phoenix.LiveView.redirect(to: "/dashboard")}
>>>>>>> 7e7d0823633caabd06c88be7ab62f310a7e52d1e

      :error ->
        {:noreply, assign(socket, error: "Invalid email or password")}
    end
  end

end
