defmodule DashboardGenWeb.UploadsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.Uploads

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uploads_list, Uploads.list_uploads())
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  # Optional: If you're still keeping a manual "Upload" button
  @impl true
  def handle_event("upload", _params, socket) do
    {:noreply, assign(socket, :uploads_list, Uploads.list_uploads())}
  end

  @impl true
  def handle_progress(:csv, entry, socket) when entry.done? do
    label = socket.assigns[:label] || "Untitled Upload"

    {results, socket} =
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

    {:noreply, socket}
  end

  def handle_progress(:csv, _entry, socket), do: {:noreply, socket}
end
