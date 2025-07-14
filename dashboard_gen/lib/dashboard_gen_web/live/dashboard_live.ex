defmodule DashboardGenWeb.DashboardLive do
  use DashboardGenWeb, :live_view, layout: {DashboardGenWeb.Layouts, :dashboard}

  alias DashboardGen.GPT
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", chart_json: nil, loading: false)}
  end

  @impl true
  def handle_event("submit", %{"query" => query}, socket) do
    send(self(), {:run_query, query})
    {:noreply, assign(socket, query: query, loading: true)}
  end

  @impl true
  def handle_info({:run_query, query}, socket) do
    case GPT.ask(query) do
      {:ok, json} ->
        {:noreply, assign(socket, chart_json: json, loading: false)}

      {:error, reason} ->
        Logger.error("GPT error: #{inspect(reason)}")
        {:noreply, assign(socket, loading: false)}
    end
  end
end
