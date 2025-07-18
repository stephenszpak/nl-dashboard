defmodule DashboardGenWeb.RegisterLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :root}
  alias DashboardGen.Accounts
  alias DashboardGen.Accounts.User

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_session(:user_id, user.id)
         |> Phoenix.LiveView.push_navigate(to: "/onboarding")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
