defmodule DashboardGenWeb.UploadsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.Uploads
  alias DashboardGen.Accounts
  require Logger

  @impl true
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
    socket =
      socket
      |> assign(:current_user, user)
      |> assign(:page_title, "Uploads")
      |> assign(:uploads_list, Uploads.list_uploads())
      |> assign(:label, "")
      |> assign(:uploading?, false)
      |> assign(:collapsed, false)
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"label" => label}, socket) do
    {:noreply, assign(socket, :label, label)}
  end

  @impl true
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_progress(:csv, entry, socket) when entry.done? do
    Logger.info("Finished uploading #{entry.client_name}")
    label = socket.assigns[:label] || "Untitled Upload"

    results =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        Uploads.create_upload(path, label)
      end)

    socket =
      case results do
        [{:ok, _upload}] ->
          put_flash(socket, :info, "Upload successful!")

        [{:error, reason}] ->
          put_flash(socket, :error, "Upload failed: #{inspect(reason)}")

        _ ->
          put_flash(socket, :error, "Unknown upload failure.")
      end
      |> assign(:uploads_list, Uploads.list_uploads())
      |> assign(:uploading?, false)

    {:noreply, socket}
  end

  def handle_progress(:csv, entry, socket) do
    Logger.debug("Upload progress #{entry.progress}% for #{entry.client_name}")
    {:noreply, assign(socket, :uploading?, true)}
  end
end
