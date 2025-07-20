defmodule DashboardGenWeb.AgentLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents

  alias DashboardGen.AutonomousAgent

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to agent updates if it's running
    if Process.whereis(AutonomousAgent) do
      Phoenix.PubSub.subscribe(DashboardGen.PubSub, "agent_updates")
    end

    {:ok,
     assign(socket,
       page_title: "Autonomous Agent",
       collapsed: false,
       agent_status: get_agent_status(),
       chat_messages: [],
       chat_input: "",
       loading_response: false
     )}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("start_agent", _params, socket) do
    case start_agent() do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "🤖 Autonomous Agent started successfully")
         |> assign(:agent_status, get_agent_status())}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start agent: #{reason}")}
    end
  end

  def handle_event("stop_agent", _params, socket) do
    stop_agent()
    {:noreply,
     socket
     |> put_flash(:info, "🤖 Autonomous Agent stopped")
     |> assign(:agent_status, get_agent_status())}
  end

  def handle_event("analyze_now", _params, socket) do
    AutonomousAgent.analyze_now()
    {:noreply, put_flash(socket, :info, "🤖 Analysis triggered manually")}
  end

  def handle_event("refresh_status", _params, socket) do
    {:noreply, assign(socket, :agent_status, get_agent_status())}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      # Add user message to chat
      user_message = %{type: :user, content: message, timestamp: DateTime.utc_now()}
      
      updated_socket = 
        socket
        |> assign(:chat_messages, [user_message | socket.assigns.chat_messages])
        |> assign(:chat_input, "")
        |> assign(:loading_response, true)

      # Send question to agent asynchronously
      Task.async(fn ->
        case AutonomousAgent.ask_question(message) do
          {:ok, response} -> {:agent_response, response}
          {:error, reason} -> {:agent_error, reason}
        end
      end)

      {:noreply, updated_socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_chat_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, :chat_input, value)}
  end

  @impl true
  def handle_info({_task_ref, {:agent_response, response}}, socket) do
    agent_message = %{type: :agent, content: response, timestamp: DateTime.utc_now()}
    
    {:noreply,
     socket
     |> assign(:chat_messages, [agent_message | socket.assigns.chat_messages])
     |> assign(:loading_response, false)}
  end

  def handle_info({_task_ref, {:agent_error, reason}}, socket) do
    error_message = %{type: :error, content: "Error: #{reason}", timestamp: DateTime.utc_now()}
    
    {:noreply,
     socket
     |> assign(:chat_messages, [error_message | socket.assigns.chat_messages])
     |> assign(:loading_response, false)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task completed, ignore
    {:noreply, socket}
  end

  def handle_info({:agent_update, update}, socket) do
    {:noreply, assign(socket, :agent_status, update)}
  end

  ## Private Functions

  defp get_agent_status do
    case Process.whereis(AutonomousAgent) do
      nil ->
        %{
          running: false,
          current_state: "stopped",
          current_task: nil,
          last_analysis: nil,
          memory_size: %{},
          scheduled_tasks: 0
        }

      _pid ->
        case AutonomousAgent.status() do
          status when is_map(status) -> Map.put(status, :running, true)
          _ -> %{running: true, current_state: "unknown"}
        end
    end
  end

  defp start_agent do
    case DynamicSupervisor.start_child(
           DashboardGen.DynamicSupervisor,
           {AutonomousAgent, []}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp stop_agent do
    case Process.whereis(AutonomousAgent) do
      nil -> :ok
      pid -> 
        DynamicSupervisor.terminate_child(DashboardGen.DynamicSupervisor, pid)
        :ok
    end
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 8)
  end

  defp format_memory_size(memory_size) when is_map(memory_size) do
    total = 
      memory_size
      |> Map.values()
      |> Enum.sum()
    
    "#{total} items"
  end
  defp format_memory_size(_), do: "0 items"
end