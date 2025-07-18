defmodule DashboardGenWeb.RegisterLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.Accounts
  alias DashboardGen.Accounts.User

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, changeset: changeset, collapsed: false, page_title: "Register")}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> DashboardGenWeb.LiveHelpers.maybe_put_session(:user_id, user.id)
         |> Phoenix.LiveView.push_navigate(to: "/onboarding")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  defp error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn {message, _opts} ->
      Phoenix.HTML.Tag.content_tag(:span, message, class: "text-red-600")
    end)
  end
end
