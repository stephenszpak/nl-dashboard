defmodule DashboardGenWeb.SidebarComponent do
  use DashboardGenWeb, :html
  alias DashboardGen.Accounts.User
  alias DashboardGen.Conversations

  attr(:collapsed, :boolean, default: false)
  attr(:current_user, User, default: nil)

  def sidebar(assigns) do
    ~H"""
    <aside
      class={[
        "bg-white border-r transition-all transform duration-200 flex flex-col h-screen md:translate-x-0",
        "absolute inset-y-0 left-0 z-20 md:static md:relative",
        @collapsed && "-translate-x-full md:w-16",
        !@collapsed && "translate-x-0 w-60"
      ]}
    >
      <div class="flex items-center justify-between px-4 py-3 border-b">
        <span :if={!@collapsed} class="font-semibold">DashboardGen</span>
        <button phx-click="toggle_sidebar" class="text-gray-500" aria-label="Toggle sidebar">
          <%= if @collapsed, do: "▶", else: "◀" %>
        </button>
      </div>
      <!-- Chat History Section -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Main Navigation -->
        <nav class="p-2 space-y-1">
          <Phoenix.Component.link navigate={~p"/"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-chart-bar"></i> <span :if={!@collapsed}>Dashboard</span>
          </Phoenix.Component.link>
          <Phoenix.Component.link navigate={~p"/chat"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-comments"></i> <span :if={!@collapsed}>AI Chat</span>
          </Phoenix.Component.link>
          <Phoenix.Component.link navigate={~p"/sentiment"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-heart-pulse"></i> <span :if={!@collapsed}>Sentiment</span>
          </Phoenix.Component.link>
          <Phoenix.Component.link navigate={~p"/insights"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-lightbulb"></i> <span :if={!@collapsed}>Insights</span>
          </Phoenix.Component.link>
          <Phoenix.Component.link navigate={~p"/agent"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-robot"></i> <span :if={!@collapsed}>AI Agent</span>
          </Phoenix.Component.link>
          <Phoenix.Component.link navigate={~p"/uploads"} class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 border-l-2 border-transparent hover:text-brandBlue hover:border-brandBlue rounded-md">
            <i class="fa-solid fa-folder-open"></i> <span :if={!@collapsed}>Uploads</span>
          </Phoenix.Component.link>
        </nav>

        <!-- Chat History List -->
        <div :if={!@collapsed} class="flex-1 px-2 mt-4 overflow-hidden flex flex-col">
          <div class="flex items-center justify-between mb-2 flex-shrink-0">
            <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Recent Chats</h3>
            <div class="flex items-center gap-1">
              <%= if @current_user do %>
                <% conversations = get_recent_conversations(@current_user.id) %>
                <%= if conversations != [] do %>
                  <button 
                    phx-click="show_clear_all_confirmation" 
                    class="p-1 text-gray-400 hover:text-red-600" 
                    title="Clear all conversations"
                  >
                    <i class="fa-solid fa-trash text-xs"></i>
                  </button>
                <% end %>
              <% end %>
              <button phx-click="new_conversation" class="p-1 text-gray-400 hover:text-gray-600" title="New conversation">
                <i class="fa-solid fa-plus text-xs"></i>
              </button>
            </div>
          </div>
          <div class="space-y-1 overflow-y-auto flex-1">
            <%= if @current_user do %>
              <% conversations = get_recent_conversations(@current_user.id) %>
              <%= if conversations == [] do %>
                <div class="text-xs text-gray-500 p-2 text-center">
                  No conversations yet
                </div>
              <% else %>
                <%= for conversation <- conversations do %>
                  <div class="flex items-center group hover:bg-gray-100 rounded-md">
                    <Phoenix.Component.link 
                      navigate={~p"/chat/conversation/#{conversation.id}"}
                      class="flex-1 min-w-0 px-3 py-2 text-xs text-gray-700 transition-colors"
                    >
                      <div class="font-medium truncate pr-2" title={conversation.title}>
                        <%= truncate_title(conversation.title, 30) %>
                      </div>
                      <div class="text-gray-500 truncate mt-1 pr-2">
                        <%= format_conversation_time(conversation.last_activity_at) %> • <%= conversation.message_count %> messages
                      </div>
                    </Phoenix.Component.link>
                    <div class="flex-shrink-0">
                      <button 
                        phx-click="show_delete_confirmation" 
                        phx-value-id={conversation.id}
                        phx-value-title={safe_title(conversation.title)}
                        class="px-2 py-2 text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity"
                        title="Delete conversation"
                      >
                        <i class="fa-solid fa-trash text-xs"></i>
                      </button>
                    </div>
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <!-- User Profile Section -->
      <div class="border-t p-3">
        <div :if={@current_user} class="flex items-center gap-3">
          <!-- Avatar -->
          <div class="w-8 h-8 bg-brandBlue rounded-full flex items-center justify-center text-white text-sm font-semibold">
            <%= if @current_user.avatar_url do %>
              <img src={@current_user.avatar_url} alt="Avatar" class="w-full h-full rounded-full object-cover">
            <% else %>
              <%= @current_user |> display_initials() %>
            <% end %>
          </div>
          
          <!-- User Info -->
          <div :if={!@collapsed} class="flex-1 min-w-0">
            <div class="text-sm font-medium text-gray-900 truncate">
              <%= display_name(@current_user) %>
            </div>
            <div class="text-xs text-gray-500 truncate">
              <%= @current_user.email %>
            </div>
          </div>
          
          <!-- Logout Button -->
          <div :if={!@collapsed}>
            <Phoenix.Component.link href="/logout" method="delete" class="p-1 text-gray-400 hover:text-gray-600">
              <i class="fa-solid fa-sign-out-alt text-sm"></i>
            </Phoenix.Component.link>
          </div>
        </div>
      </div>
    </aside>
    """
  end

  # Helper functions for user display
  defp display_name(%User{} = user) do
    User.display_name(user)
  end
  defp display_name(_), do: "Guest"

  defp display_initials(%User{} = user) do
    User.initials(user)
  end
  defp display_initials(_), do: "G"
  
  defp get_recent_conversations(user_id) do
    Conversations.list_user_conversations(user_id, limit: 10)
  rescue
    _ -> []
  end
  
  defp format_conversation_time(datetime) do
    case datetime do
      %DateTime{} ->
        now = DateTime.utc_now()
        diff = DateTime.diff(now, datetime, :second)
        
        cond do
          diff < 60 -> "Just now"
          diff < 3600 -> "#{div(diff, 60)}m ago"
          diff < 86400 -> "#{div(diff, 3600)}h ago"
          diff < 604800 -> "#{div(diff, 86400)}d ago"
          true -> 
            datetime
            |> DateTime.to_date()
            |> Date.to_string()
        end
      _ -> "Unknown"
    end
  end
  
  defp truncate_title(title, max_length) when is_binary(title) and title != "" do
    if String.length(title) > max_length do
      String.slice(title, 0, max_length) <> "..."
    else
      title
    end
  end
  defp truncate_title(title, _) when is_binary(title), do: "Untitled"
  defp truncate_title(_, _), do: "Untitled"
  
  defp safe_title(title) when is_binary(title) and title != "", do: title
  defp safe_title(_), do: "Untitled"
end
