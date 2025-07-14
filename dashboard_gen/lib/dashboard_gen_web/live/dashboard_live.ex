defmodule DashboardGenWeb.DashboardLive do
  use DashboardGenWeb, :live_view

  alias DashboardGen.GPT

  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", result: nil)}
  end

  def handle_event("submit", %{"query" => query}, socket) do
    case GPT.ask(query) do
      {:ok, json} -> {:noreply, assign(socket, result: json, query: query)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "#{inspect(reason)}")}
    end
  end
end
