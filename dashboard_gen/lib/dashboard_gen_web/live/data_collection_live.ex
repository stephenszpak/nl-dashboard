defmodule DashboardGenWeb.DataCollectionLive do
  @moduledoc """
  LiveView for monitoring and managing data collection processes.
  Shows real-time status, configuration, and allows manual control.
  """
  
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers
  
  alias DashboardGen.DataCollectors.{Configuration, StatusMonitor, DataCollectorSupervisor}
  
  @impl true
  def mount(_params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        # Subscribe to status updates
        Phoenix.PubSub.subscribe(DashboardGen.PubSub, "data_collector_status")
        Phoenix.PubSub.subscribe(DashboardGen.PubSub, "data_collector_config")
        
        {:ok, assign_initial_state(socket)}
    end
  end
  
  @impl true
  def handle_info({:status_update, status}, socket) do
    {:noreply, assign(socket, collector_status: status)}
  end
  
  def handle_info({:config_updated, _changes}, socket) do
    # Reload configuration when it changes
    config = Configuration.get_config()
    {:noreply, assign(socket, config: config)}
  end
  
  @impl true
  def handle_event("force_collection", %{"collector" => collector_type}, socket) do
    case collector_type do
      "social_media" ->
        DashboardGen.DataCollectors.SocialMediaCollector.force_collection()
        {:noreply, put_flash(socket, :info, "Forced social media collection")}
      
      "news" ->
        DashboardGen.DataCollectors.NewsCollector.force_collection()
        {:noreply, put_flash(socket, :info, "Forced news collection")}
      
      "processor" ->
        DashboardGen.DataCollectors.DataProcessor.force_processing()
        {:noreply, put_flash(socket, :info, "Forced data processing")}
      
      _ ->
        {:noreply, put_flash(socket, :error, "Unknown collector type")}
    end
  end
  
  def handle_event("restart_collector", %{"collector" => collector_type}, socket) do
    case DataCollectorSupervisor.restart_collector(String.to_atom(collector_type)) do
      :ok ->
        {:noreply, put_flash(socket, :info, "Restarted #{collector_type} collector")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to restart collector: #{inspect(reason)}")}
    end
  end
  
  def handle_event("add_company", %{"company" => company}, socket) when company != "" do
    case Configuration.add_company(String.trim(company)) do
      :ok ->
        config = Configuration.get_config()
        socket = assign(socket, config: config)
        {:noreply, put_flash(socket, :info, "Added company: #{company}")}
      {:error, :already_exists} ->
        {:noreply, put_flash(socket, :warning, "Company already exists")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add company: #{inspect(reason)}")}
    end
  end
  
  def handle_event("add_company", _params, socket) do
    {:noreply, put_flash(socket, :error, "Company name cannot be empty")}
  end
  
  def handle_event("remove_company", %{"company" => company}, socket) do
    case Configuration.remove_company(company) do
      :ok ->
        config = Configuration.get_config()
        socket = assign(socket, config: config)
        {:noreply, put_flash(socket, :info, "Removed company: #{company}")}
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to remove company: #{inspect(reason)}")}
    end
  end
  
  def handle_event("toggle_source", %{"source" => source, "action" => action}, socket) do
    source_atom = String.to_atom(source)
    
    case action do
      "enable" ->
        case Configuration.enable_source(source_atom) do
          :ok ->
            config = Configuration.get_config()
            {:noreply, assign(socket, config: config) |> put_flash(:info, "Enabled #{source}")}
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to enable #{source}: #{inspect(reason)}")}
        end
      
      "disable" ->
        case Configuration.disable_source(source_atom) do
          :ok ->
            config = Configuration.get_config()
            {:noreply, assign(socket, config: config) |> put_flash(:info, "Disabled #{source}")}
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to disable #{source}: #{inspect(reason)}")}
        end
    end
  end
  
  def handle_event("clear_alerts", _params, socket) do
    StatusMonitor.clear_alerts()
    {:noreply, put_flash(socket, :info, "Cleared all alerts")}
  end
  
  defp assign_initial_state(socket) do
    config = Configuration.get_config()
    status = StatusMonitor.get_status()
    detailed_status = StatusMonitor.get_detailed_status()
    
    assign(socket,
      page_title: "Data Collection",
      config: config,
      collector_status: status,
      detailed_status: detailed_status,
      collapsed: false
    )
  end
  
  defp format_timestamp(nil), do: "Never"
  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
      _ -> timestamp
    end
  end
  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end
  defp format_timestamp(_), do: "Unknown"
  
  defp status_color(:healthy), do: "text-green-600 bg-green-100"
  defp status_color(:running), do: "text-green-600 bg-green-100"
  defp status_color(:degraded), do: "text-yellow-600 bg-yellow-100"
  defp status_color(:critical), do: "text-red-600 bg-red-100"
  defp status_color(:not_running), do: "text-gray-600 bg-gray-100"
  defp status_color(:error), do: "text-red-600 bg-red-100"
  defp status_color(:timeout), do: "text-orange-600 bg-orange-100"
  defp status_color(_), do: "text-gray-600 bg-gray-100"
  
  defp alert_severity_color(:critical), do: "text-red-600 bg-red-100"
  defp alert_severity_color(:high), do: "text-red-600 bg-red-50"
  defp alert_severity_color(:medium), do: "text-yellow-600 bg-yellow-50"
  defp alert_severity_color(:low), do: "text-blue-600 bg-blue-50"
  defp alert_severity_color(_), do: "text-gray-600 bg-gray-50"
end