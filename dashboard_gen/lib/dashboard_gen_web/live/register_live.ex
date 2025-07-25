defmodule DashboardGenWeb.RegisterLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :auth}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.Accounts
  alias DashboardGen.Accounts.User

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, changeset: changeset, page_title: "Register")}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        case Accounts.create_session(user.id) do
          {:ok, session} ->
            {:noreply,
             socket
             |> Phoenix.LiveView.put_session(:session_token, session.token)
             |> Phoenix.LiveView.put_session(:user_id, user.id)
             |> Phoenix.LiveView.redirect(to: "/onboarding")}

          {:error, _} ->
            changeset =
              User.registration_changeset(%User{}, user_params)
              |> Ecto.Changeset.add_error(
                :password,
                "Unable to create session. Please try again."
              )

            {:noreply, assign(socket, changeset: changeset)}
        end

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
