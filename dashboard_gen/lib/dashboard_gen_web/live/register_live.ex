defmodule DashboardGenWeb.RegisterLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :root}
  use DashboardGenWeb, :html

  alias DashboardGen.Accounts
  alias DashboardGen.Accounts.User

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created, please log in.")
         |> Phoenix.LiveView.push_navigate(to: "/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn {message, _opts} ->
      Phoenix.HTML.Tag.content_tag(:span, message, class: "text-red-600")
    end)
  end
end
