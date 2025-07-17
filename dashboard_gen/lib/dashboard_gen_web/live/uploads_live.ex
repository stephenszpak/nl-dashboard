defmodule DashboardGenWeb.UploadsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html

  alias DashboardGen.Uploads

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uploads_list, Uploads.list_uploads())
      |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, auto_upload: false)

    {:ok, socket}
  end

  @impl true
  def handle_event("upload", params, socket) do
    label = Map.get(params, "label", nil)
    entries = uploaded_entries(socket, :csv)

    socket =
      if entries == [] do
        put_flash(socket, :error, "No file selected")
      else
        {results, socket} =
          consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
            Uploads.create_upload(path, label)
          end)

        case results do
          [{:ok, _}] ->
            put_flash(socket, :info, "Upload saved")

          [{:error, reason}] ->
            put_flash(socket, :error, "Failed: #{inspect(reason)}")

          _ ->
            put_flash(socket, :error, "Upload failed")
        end
      end
      |> assign(:uploads_list, Uploads.list_uploads())

    {:noreply, socket}
  end
end
