defmodule DashboardGenWeb.CompetitorInsightsLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers

  alias DashboardGen.Insights
  alias DashboardGen.Conversations

  @impl true
  def mount(_params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        insights = Insights.list_recent_insights_by_company()
    companies = Enum.map(insights, &elem(&1, 0))

    summaries =
      Enum.into(companies, %{}, fn company ->
        case Insights.generate_topic_summary(company) do
          {:ok, summary} -> {company, summary}
          _ -> {company, nil}
        end
      end)

    loading =
      summaries
      |> Enum.filter(fn {_c, s} -> is_nil(s) end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    Enum.each(loading, fn company -> send(self(), {:generate_summary, company}) end)

    {:ok,
     assign(socket,
       page_title: "Competitor Insights",
       collapsed: false,
       insights_by_company: insights,
       all_insights: insights,  # Store original unfiltered data
       companies: companies,
       summaries: summaries,
       loading_summaries: loading,
       # Filter state
       filters: %{
         company: "all",
         content_type: "all", 
         date_range: "all",
         keyword: ""
       },
       # UI state
       show_filters: false,
       # Modal state
       show_delete_modal: false,
       show_clear_all_modal: false,
       delete_conversation_id: nil,
       delete_conversation_title: nil
     )}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, update(socket, :show_filters, &(!&1))}
  end

  def handle_event("update_filters", params, socket) do
    new_filters = %{
      company: Map.get(params, "company", socket.assigns.filters.company),
      content_type: Map.get(params, "content_type", socket.assigns.filters.content_type),
      date_range: Map.get(params, "date_range", socket.assigns.filters.date_range),
      keyword: Map.get(params, "keyword", socket.assigns.filters.keyword)
    }
    
    filtered_insights = apply_filters(socket.assigns.all_insights, new_filters)
    
    {:noreply, 
     socket
     |> assign(:filters, new_filters)
     |> assign(:insights_by_company, filtered_insights)}
  end

  def handle_event("clear_filters", _params, socket) do
    default_filters = %{
      company: "all",
      content_type: "all", 
      date_range: "all",
      keyword: ""
    }
    
    {:noreply, 
     socket
     |> assign(:filters, default_filters)
     |> assign(:insights_by_company, socket.assigns.all_insights)}
  end

  # Sidebar conversation deletion handlers
  def handle_event("show_delete_confirmation", %{"id" => conversation_id} = params, socket) do
    title = Map.get(params, "title", "Untitled")
    safe_title = case title do
      t when is_binary(t) and byte_size(t) > 0 -> String.trim(t)
      _ -> "Untitled"
    end
    
    {:noreply, 
     assign(socket,
       show_delete_modal: true,
       delete_conversation_id: conversation_id,
       delete_conversation_title: safe_title
     )}
  end

  def handle_event("close_delete_modal", _params, socket) do
    {:noreply, 
     assign(socket,
       show_delete_modal: false,
       delete_conversation_id: nil,
       delete_conversation_title: nil
     )}
  end

  def handle_event("confirm_delete_conversation", _params, socket) do
    if socket.assigns[:delete_conversation_id] do
      case Conversations.get_conversation(socket.assigns.delete_conversation_id) do
        {:ok, conversation} ->
          case Conversations.delete_conversation(conversation) do
            {:ok, _} ->
              if socket.assigns[:current_conversation] && socket.assigns.current_conversation.id == conversation.id do
                {:noreply, 
                 socket
                 |> assign(show_delete_modal: false, delete_conversation_id: nil, delete_conversation_title: nil)
                 |> put_flash(:info, "Conversation deleted")
                 |> push_navigate(to: "/")}
              else
                {:noreply, 
                 socket
                 |> assign(show_delete_modal: false, delete_conversation_id: nil, delete_conversation_title: nil)
                 |> put_flash(:info, "Conversation deleted")}
              end
            
            {:error, _} ->
              {:noreply, 
               socket
               |> assign(show_delete_modal: false, delete_conversation_id: nil, delete_conversation_title: nil)
               |> put_flash(:error, "Failed to delete conversation")}
          end
        
        {:error, :not_found} ->
          {:noreply, 
           socket
           |> assign(show_delete_modal: false, delete_conversation_id: nil, delete_conversation_title: nil)
           |> put_flash(:error, "Conversation not found")}
      end
    else
      {:noreply, 
       socket
       |> assign(show_delete_modal: false, delete_conversation_id: nil, delete_conversation_title: nil)
       |> put_flash(:error, "No conversation selected")}
    end
  end

  def handle_event("show_clear_all_confirmation", _params, socket) do
    {:noreply, assign(socket, show_clear_all_modal: true)}
  end

  def handle_event("close_clear_all_modal", _params, socket) do
    {:noreply, assign(socket, show_clear_all_modal: false)}
  end

  def handle_event("confirm_clear_all_conversations", _params, socket) do
    case Conversations.delete_all_user_conversations(socket.assigns.current_user.id) do
      {_count, _} ->
        {:noreply, 
         socket
         |> assign(show_clear_all_modal: false)
         |> put_flash(:info, "All conversations deleted")}
      
      {:error, _} ->
        {:noreply, 
         socket
         |> assign(show_clear_all_modal: false)
         |> put_flash(:error, "Failed to delete conversations")}
    end
  end

  def handle_event("modal_content_click", _params, socket) do
    # Prevent modal from closing when clicking inside content
    {:noreply, socket}
  end

  def handle_event("new_conversation", _params, socket) do
    {:noreply, push_navigate(socket, to: "/")}
  end

  @impl true
  def handle_info({:generate_summary, company}, socket) do
    case Insights.generate_topic_summary(company) do
      {:ok, summary} ->
        socket =
          socket
          |> update(:summaries, &Map.put(&1, company, summary))
          |> update(:loading_summaries, &MapSet.delete(&1, company))

        {:noreply, socket}

      _ ->
        {:noreply, update(socket, :loading_summaries, &MapSet.delete(&1, company))}
    end
  end

  defp snippet(text, len \\ 140)
  defp snippet(nil, _len), do: ""

  defp snippet(text, len) do
    text
    |> String.replace("\n", " ")
    |> String.slice(0, len)
    |> String.trim()
  end

  defp platform_icon(url) do
    cond do
      is_nil(url) -> "chat-bubble-left-right"
      String.contains?(url, "twitter") -> "twitter"
      String.contains?(url, "linkedin") -> "linkedin"
      String.contains?(url, "youtube") -> "play"
      true -> "chat-bubble-left-right"
    end
  end

  defp format_number(nil), do: "0"
  defp format_number(num) when is_integer(num) and num >= 0 do
    cond do
      num >= 1_000_000 -> "#{Float.round(num / 1_000_000, 1)}M"
      num >= 1_000 -> "#{Float.round(num / 1_000, 1)}K"
      true -> Integer.to_string(num)
    end
  end
  defp format_number(num) when is_binary(num) do
    case Integer.parse(num) do
      {parsed_num, ""} when parsed_num >= 0 -> format_number(parsed_num)
      _ -> "0"
    end
  end
  defp format_number(_), do: "0"

  # Filter application logic
  defp apply_filters(insights_by_company, filters) do
    insights_by_company
    |> Enum.map(fn {company, data} ->
      # Filter by company
      if filters.company == "all" or filters.company == company do
        filtered_data = %{
          press_releases: filter_items(data.press_releases, filters, "press_release"),
          social_media: filter_items(data.social_media, filters, "social_media")
        }
        {company, filtered_data}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp filter_items(items, filters, item_type) do
    items
    |> Enum.filter(fn item ->
      # Content type filter
      content_type_match = case filters.content_type do
        "all" -> true
        "press_releases" -> item_type == "press_release"
        "social_media" -> item_type == "social_media"
        _ -> true
      end

      # Date range filter
      date_match = case filters.date_range do
        "all" -> true
        "last_week" -> within_days?(item.date, 7)
        "last_month" -> within_days?(item.date, 30)
        "last_3_months" -> within_days?(item.date, 90)
        _ -> true
      end

      # Keyword search
      keyword_match = if filters.keyword == "" do
        true
      else
        keyword = String.downcase(filters.keyword)
        title_match = String.contains?(String.downcase(item.title || ""), keyword)
        content_match = String.contains?(String.downcase(item.content || ""), keyword)
        summary_match = String.contains?(String.downcase(item.summary || ""), keyword)
        title_match or content_match or summary_match
      end

      content_type_match and date_match and keyword_match
    end)
  end

  defp within_days?(date_string, days) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        cutoff = Date.add(Date.utc_today(), -days)
        Date.compare(date, cutoff) != :lt
      {:error, _} -> 
        # If date parsing fails, include the item
        true
    end
  end

  defp total_results(insights_by_company) do
    insights_by_company
    |> Enum.reduce(0, fn {_company, data}, acc ->
      press_count = length(data.press_releases)
      social_count = length(data.social_media)
      acc + press_count + social_count
    end)
  end
end
