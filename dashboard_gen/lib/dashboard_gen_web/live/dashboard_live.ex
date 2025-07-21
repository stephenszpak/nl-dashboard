defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  import DashboardGenWeb.AuthHelpers
  alias DashboardGen.GPTClient
  alias DashboardGen.Codex.Summarizer
  alias DashboardGen.Codex.Explainer
  alias DashboardGen.Uploads
  alias DashboardGen.AnomalyDetector
  alias DashboardGen.CompetitivePrompts
  alias DashboardGen.{Insights, CodexClient, Analytics, Conversations}
  alias DashboardGen.Conversations.Conversation
  alias VegaLite

  @impl true
  def mount(%{"conversation_id" => conversation_id}, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        # Load specific conversation for authenticated user
        case Conversations.get_conversation(conversation_id, socket.assigns.current_user.id) do
          %Conversation{} = conversation ->
            messages = Conversations.list_conversation_messages(conversation.id)
            {:ok, assign_conversation_state(socket, conversation, messages)}
          nil ->
            {:ok, redirect(socket, to: "/")}
        end
    end
  end
  
  def mount(params, session, socket) do
    user = get_current_user(session)
    case require_authentication(socket, user) do
      {:error, redirect_socket} ->
        {:ok, redirect_socket}
      {:ok, socket} ->
        # Load conversation state for authenticated user
        # Check if this is a request for a new conversation
        case Map.get(params, "new") do
          "true" ->
            # Start with empty state for new conversation
            {:ok, assign_empty_state(socket)}
          _ ->
            # Load most recent conversation or start empty
            case Conversations.get_most_recent_conversation(socket.assigns.current_user.id) do
              %Conversation{} = conversation ->
                messages = Conversations.list_conversation_messages(conversation.id)
                {:ok, assign_conversation_state(socket, conversation, messages)}
              nil ->
                # No conversations yet, start with empty state
                {:ok, assign_empty_state(socket)}
            end
        end
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) when content != "" do
    user = socket.assigns.current_user
    content = String.trim(content)
    
    # Create or get conversation
    {conversation, messages} = case socket.assigns.current_conversation do
      nil ->
        # Create new conversation
        case Conversations.create_conversation_with_message(user.id, content) do
          {:ok, conversation} -> 
            {conversation, conversation.messages}
          {:error, _} ->
            {nil, []}
        end
      conv ->
        # Add message to existing conversation
        case Conversations.add_message(conv.id, content, "user") do
          {:ok, msg} ->
            existing_messages = socket.assigns.messages || []
            {conv, existing_messages ++ [msg]}
          {:error, _} ->
            {conv, socket.assigns.messages || []}
        end
    end
    
    if conversation do
      # Send the message for AI processing
      send(self(), {:process_ai_response, content, conversation.id})
      
      {:noreply,
       assign(socket,
         current_conversation: conversation,
         messages: messages,
         current_message: "",
         loading: true
       )}
    else
      {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end
  
  def handle_event("send_message", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("update_message", %{"message" => content}, socket) do
    {:noreply, assign(socket, :current_message, content)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :collapsed, &(!&1))}
  end

  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, 
      mode: mode,
      prompt: "",
      chart_spec: nil,
      competitive_analysis: nil,
      analytics_charts: [],
      summary: nil,
      explanation: nil,
      alerts: nil,
      show_prompt_categories: false
    )}
  end

  def handle_event("toggle_prompt_categories", _params, socket) do
    {:noreply, update(socket, :show_prompt_categories, &(!&1))}
  end

  def handle_event("use_prompt", %{"prompt" => prompt}, socket) do
    # Always ensure we have the raw prompt first, then contextualize it
    cleaned_prompt = String.trim(prompt)
    contextualized_prompt = CompetitivePrompts.contextualize_prompt(cleaned_prompt)
    
    # Log prompt usage for monitoring
    require Logger
    Logger.debug("Using prompt template: #{String.slice(prompt, 0, 50)}...")
    
    {:noreply, 
     socket
     |> assign(
       prompt: contextualized_prompt,
       show_prompt_categories: false
     )
     |> put_flash(:info, "✅ Prompt template added to input")
     |> push_event("focus_input", %{})}
  end

  def handle_event("use_suggestion", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, 
      prompt: prompt,
      mode: "competitive_intelligence"
    )}
  end

  def handle_event("refresh_suggestions", _params, socket) do
    {:noreply, assign(socket, smart_suggestions: CompetitivePrompts.get_smart_suggestions())}
  end

  def handle_event("run_scrapers", _params, socket) do
    Task.start(fn -> DashboardGen.Scrapers.scrape_all() end)
    {:noreply, put_flash(socket, :info, "Scrapers started")}
  end

  def handle_event("show_agent_health", _params, socket) do
    case ensure_agent_monitor() do
      {:ok, health_status} ->
        {:noreply, assign(socket, 
          show_dev_modal: true,
          dev_modal_title: "🔧 Agent Health Status",
          dev_modal_content: format_health_status(health_status)
        )}
      {:error, reason} ->
        {:noreply, assign(socket,
          show_dev_modal: true,
          dev_modal_title: "🔧 Agent Health Status",
          dev_modal_content: format_error_message("Agent Monitor", reason)
        )}
    end
  end

  def handle_event("show_recent_alerts", _params, socket) do
    case ensure_alert_store() do
      {:ok, alerts} ->
        {:noreply, assign(socket,
          show_dev_modal: true,
          dev_modal_title: "🚨 Recent Alerts",
          dev_modal_content: format_recent_alerts(alerts)
        )}
      {:error, reason} ->
        {:noreply, assign(socket,
          show_dev_modal: true,
          dev_modal_title: "🚨 Recent Alerts", 
          dev_modal_content: format_error_message("Alert Store", reason)
        )}
    end
  end

  def handle_event("run_system_tests", _params, socket) do
    # Start tests asynchronously and show loading state
    send(self(), :run_system_tests_async)
    {:noreply, assign(socket,
      show_dev_modal: true,
      dev_modal_title: "🧪 Running System Tests...",
      dev_modal_content: format_test_loading()
    )}
  end

  def handle_event("close_dev_modal", _params, socket) do
    {:noreply, assign(socket, show_dev_modal: false)}
  end
  
  def handle_event("new_conversation", _params, socket) do
    # Focus the input after a short delay to ensure DOM is updated
    Process.send_after(self(), :focus_input, 100)
    
    {:noreply, 
     socket
     |> assign_empty_state()
     |> put_flash(:info, "✨ Started new conversation")
     |> push_navigate(to: "/?new=true")}
  end
  
  def handle_event("load_conversation", %{"id" => conversation_id}, socket) do
    {:noreply, push_navigate(socket, to: "/conversation/#{conversation_id}")}
  end

  def handle_event("modal_content_click", _params, socket) do
    # Prevent modal from closing when clicking inside content
    {:noreply, socket}
  end

  def handle_event("generate_summary", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, summary} <-
           Summarizer.summarize(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, summary: summary)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  def handle_event("explain_this", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, explanation} <-
           Explainer.explain(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, explanation: explanation)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  def handle_event("why_this", _params, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, explanation} <-
           Explainer.why(
             socket.assigns.prompt,
             Map.values(upload.headers),
             upload.data
           ) do
      {:noreply, assign(socket, explanation: explanation)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}

      nil ->
        {:noreply, put_flash(socket, :error, "No upload found")}
    end
  end

  @impl true
  def handle_info(:run_system_tests_async, socket) do
    # Run system tests and update modal content
    test_results = run_system_tests()
    
    {:noreply, assign(socket,
      dev_modal_title: "🧪 System Test Results",
      dev_modal_content: format_test_results(test_results)
    )}
  end

  @impl true
  def handle_info({:process_ai_response, user_content, conversation_id}, socket) do
    case analyze_competitive_intelligence(user_content) do
      {:ok, ai_response} ->
        # Standard text response
        case Conversations.add_message(conversation_id, ai_response, "assistant") do
          {:ok, ai_message} ->
            updated_messages = (socket.assigns.messages || []) ++ [ai_message]
            
            {:noreply,
             assign(socket,
               messages: updated_messages,
               loading: false
             )}
          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to save AI response")
             |> assign(loading: false)}
        end
        
      {:ok, analysis, chart_data} ->
        # Chart response with data
        full_response = "#{analysis}\n\n[CHART_DATA]:#{Jason.encode!(chart_data)}"
        
        case Conversations.add_message(conversation_id, full_response, "assistant") do
          {:ok, ai_message} ->
            updated_messages = (socket.assigns.messages || []) ++ [ai_message]
            
            {:noreply,
             assign(socket,
               messages: updated_messages,
               loading: false
             )}
          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to save AI response")
             |> assign(loading: false)}
        end
      
      {:error, reason} ->
        error_message = cond do
          is_binary(reason) and String.contains?(reason, "Connection error") ->
            "🔌 Unable to connect to AI service. Please check your internet connection and try again."
          is_binary(reason) and String.contains?(reason, "OPENAI_API_KEY") ->
            "⚙️ AI service configuration error. Please contact support."
          is_binary(reason) and String.contains?(reason, "timeout") ->
            "⏱️ Analysis is taking longer than expected. Please try a shorter question."
          true ->
            "❌ Analysis failed. Please try again or rephrase your question."
        end
        
        {:noreply,
         socket
         |> put_flash(:error, error_message)
         |> assign(loading: false)}
    end
  end

  @impl true
  def handle_info({:generate_chart, prompt}, socket) do
    with %Uploads.Upload{} = upload <- Uploads.latest_upload(),
         {:ok, spec} <- GPTClient.get_chart_spec(prompt, upload.headers),
         %{"charts" => [chart_spec | _]} <- spec,
         {:ok, long_data} <- prepare_long_data(upload, chart_spec) do
      vl =
        VegaLite.new(%{"title" => chart_spec["title"]})
        |> VegaLite.data_from_values(long_data)
        |> VegaLite.mark(String.to_atom(chart_spec["type"]))
        |> VegaLite.encode(:x, field: "x", type: :nominal)
        |> VegaLite.encode(:y, field: "value", type: :quantitative)
        |> VegaLite.encode(:color, field: "category", type: :nominal)

      spec = VegaLite.to_spec(vl) |> Jason.encode!()

      alerts =
        with {:ok, anomalies} <- AnomalyDetector.detect_anomalies(upload.headers, upload.data),
             true <- anomalies != [],
             {:ok, summary} <- AnomalyDetector.summarize_anomalies(anomalies) do
          summary
        else
          {:ok, []} -> nil
          _ -> nil
        end

      {:noreply,
       assign(socket,
         chart_spec: spec,
         loading: false,
         summary: nil,
         explanation: nil,
         alerts: alerts
       )}
    else
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)
         |> assign(loading: false, alerts: nil)}
    end
  end

  def handle_info(:focus_input, socket) do
    {:noreply, push_event(socket, "focus", %{to: "#message-input"})}
  end

  # Conversation state management helpers
  
  defp assign_conversation_state(socket, conversation, messages) do
    assign(socket,
      page_title: conversation.title,
      current_conversation: conversation,
      messages: messages,
      current_message: "",
      loading: false,
      collapsed: false,
      show_prompt_categories: false,
      prompt_categories: CompetitivePrompts.get_categories(),
      smart_suggestions: CompetitivePrompts.get_smart_suggestions(),
      show_dev_modal: false,
      dev_modal_title: "",
      dev_modal_content: ""
    )
  end
  
  defp assign_empty_state(socket) do
    assign(socket,
      page_title: "New Conversation",
      current_conversation: nil,
      messages: [],
      current_message: "",
      loading: false,
      collapsed: false,
      show_prompt_categories: false,
      prompt_categories: CompetitivePrompts.get_categories(),
      smart_suggestions: CompetitivePrompts.get_smart_suggestions(),
      show_dev_modal: false,
      dev_modal_title: "",
      dev_modal_content: ""
    )
  end

  defp prepare_long_data(upload, chart_spec) do
    x_field = Uploads.resolve_field(chart_spec["x"], upload.headers)
    y_fields = Enum.map(chart_spec["y"] || [], &Uploads.resolve_field(&1, upload.headers))

    color_field =
      chart_spec["color"] ||
        chart_spec["group_by"]
        |> Uploads.resolve_field(upload.headers)

    unresolved =
      []
      |> maybe_add_unresolved(x_field, chart_spec["x"])
      |> maybe_add_unresolved_list(y_fields, chart_spec["y"] || [])
      |> maybe_add_unresolved(color_field, chart_spec["color"] || chart_spec["group_by"])

    cond do
      unresolved != [] ->
        {:error, "Could not resolve fields: #{Enum.join(unresolved, ", ")}"}

      Enum.empty?(upload.data) ->
        {:error, "No data available"}

      true ->
        long_data =
          Enum.flat_map(upload.data, fn row ->
            Enum.map(y_fields, fn y_field ->
              category =
                cond do
                  color_field -> Map.get(row, color_field)
                  true -> upload.headers[y_field] || y_field
                end

              %{
                "x" => Map.get(row, x_field),
                "value" => Map.get(row, y_field),
                "category" => category
              }
            end)
          end)

        {:ok, long_data}
    end
  end

  defp maybe_add_unresolved(list, nil, original) when is_binary(original), do: [original | list]
  defp maybe_add_unresolved(list, _resolved, _original), do: list

  defp maybe_add_unresolved_list(list, resolved_list, originals) do
    originals
    |> Enum.zip(resolved_list)
    |> Enum.reduce(list, fn
      {orig, nil}, acc -> [orig | acc]
      {_, _}, acc -> acc
    end)
  end

  defp analyze_competitive_intelligence(prompt) do
    # Determine if this is an analytics question or competitive intelligence question
    if is_analytics_question?(prompt) do
      Analytics.analyze_question(prompt)
    else
      analyze_competitor_intelligence(prompt)
    end
  end
  
  defp analyze_competitor_intelligence(prompt) do
    # Get recent competitor insights
    recent_insights = Insights.list_recent_insights_by_company(10)
    
    # Prepare context for analysis
    context = build_competitive_context(recent_insights)
    
    # Create enhanced prompt with context
    enhanced_prompt = """
    You are a competitive intelligence analyst. Analyze the following prompt using the provided competitor data.

    User Query: #{prompt}

    Recent Competitor Activity:
    #{context}

    Provide a detailed analysis including:
    1. Key findings and insights
    2. Strategic implications 
    3. Recommended actions
    4. Risk assessment
    5. Opportunities identified

    Format your response in clear sections with actionable insights.
    """

    case CodexClient.ask(enhanced_prompt) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp is_analytics_question?(prompt) do
    analytics_keywords = [
      "homepage", "website", "alliancebernstein.com", "fund search", "page", "traffic",
      "conversion", "bounce", "engagement", "user", "visitor", "session", "click",
      "navigation", "behavior", "analytics", "performance", "mobile", "desktop"
    ]
    
    prompt_lower = String.downcase(prompt)
    Enum.any?(analytics_keywords, &String.contains?(prompt_lower, &1))
  end

  defp build_competitive_context(recent_insights) do
    recent_insights
    |> Enum.map(fn {company, data} ->
      press_count = length(data.press_releases)
      social_count = length(data.social_media)
      
      recent_titles = 
        (data.press_releases ++ data.social_media)
        |> Enum.take(3)
        |> Enum.map(& &1.title)
        |> Enum.join("; ")
      
      "#{company}: #{press_count} press releases, #{social_count} social posts. Recent: #{recent_titles}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Build a sample VegaLite chart using inline mock data.
  """
  def sample_chart do
    data = [
      %{"Month" => "Jan", "Ad Spend" => 1000, "Conversions" => 50},
      %{"Month" => "Feb", "Ad Spend" => 1200, "Conversions" => 65},
      %{"Month" => "Mar", "Ad Spend" => 1500, "Conversions" => 80}
    ]

    long_data =
      Enum.flat_map(data, fn row ->
        ["Ad Spend", "Conversions"]
        |> Enum.map(fn category ->
          %{
            "x" => row["Month"],
            "category" => category,
            "value" => row[category]
          }
        end)
      end)

    VegaLite.new(%{"title" => "Ad Spend and Conversions by Month"})
    |> VegaLite.data_from_values(long_data)
    |> VegaLite.mark(:bar)
    |> VegaLite.encode(:x, field: "x", type: :nominal)
    |> VegaLite.encode(:y, field: "value", type: :quantitative)
    |> VegaLite.encode(:color, field: "category", type: :nominal)
  end
  
  # These chart generation functions have been moved to DashboardGen.Analytics module
  
  # GenServer Startup Helpers
  
  defp ensure_alert_store do
    try do
      # First check if the GenServer is alive
      case GenServer.whereis(DashboardGen.AlertStore) do
        pid when is_pid(pid) ->
          # GenServer exists, try to get alerts
          alerts = DashboardGen.AlertStore.get_recent_alerts(10)
          {:ok, alerts}
        nil ->
          # GenServer doesn't exist, try to start it
          case DashboardGen.AlertStore.start_link([]) do
            {:ok, _pid} -> 
              Process.sleep(200)
              alerts = DashboardGen.AlertStore.get_recent_alerts(10)
              {:ok, alerts}
            {:error, {:already_started, _pid}} ->
              alerts = DashboardGen.AlertStore.get_recent_alerts(10)
              {:ok, alerts}
            {:error, reason} ->
              {:error, "Failed to start Alert Store: #{inspect(reason)}"}
          end
      end
    rescue
      error -> {:error, "Alert Store error: #{inspect(error)}"}
    end
  end
  
  defp ensure_agent_monitor do
    try do
      # First check if the GenServer is alive
      case GenServer.whereis(DashboardGen.AgentMonitor) do
        pid when is_pid(pid) ->
          # GenServer exists, try to get health status
          health = DashboardGen.AgentMonitor.get_health_status()
          {:ok, health}
        nil ->
          # GenServer doesn't exist, try to start it
          case DashboardGen.AgentMonitor.start_link([]) do
            {:ok, _pid} ->
              Process.sleep(200)
              health = DashboardGen.AgentMonitor.get_health_status()
              {:ok, health}
            {:error, {:already_started, _pid}} ->
              health = DashboardGen.AgentMonitor.get_health_status()
              {:ok, health}
            {:error, reason} ->
              {:error, "Failed to start Agent Monitor: #{inspect(reason)}"}
          end
      end
    rescue
      error -> {:error, "Agent Monitor error: #{inspect(error)}"}
    end
  end
  
  # Developer Dashboard Helper Functions
  
  defp run_system_tests do
    try do
      # Test each major system component
      results = %{
        agent_monitor: test_agent_monitor(),
        alert_store: test_alert_store(),
        agent_router: test_agent_router(),
        content_tagging: test_content_tagging(),
        local_inference: test_local_inference(),
        prompt_drift: test_prompt_drift(),
        agent_coordinator: test_agent_coordinator()
      }
      
      overall_status = if Enum.all?(results, fn {_key, result} -> result.status == :ok end) do
        :all_passed
      else
        :some_failed
      end
      
      Map.put(results, :overall_status, overall_status)
    rescue
      error ->
        %{
          overall_status: :error,
          error: "Test execution failed: #{inspect(error)}"
        }
    end
  end
  
  defp test_agent_monitor do
    try do
      case ensure_agent_monitor() do
        {:ok, health} ->
          %{status: :ok, message: "Agent Monitor operational", details: "Uptime: #{health.uptime_seconds}s"}
        {:error, reason} ->
          %{status: :warning, message: "Agent Monitor startup needed", details: reason}
      end
    rescue
      error ->
        %{status: :error, message: "Agent Monitor test failed", details: "#{inspect(error)}"}
    end
  end
  
  defp test_alert_store do
    try do
      case ensure_alert_store() do
        {:ok, _alerts} ->
          try do
            case DashboardGen.AlertStore.get_alert_stats() do
              stats when is_map(stats) ->
                %{status: :ok, message: "Alert Store operational", details: "Total alerts: #{stats.total_alerts}"}
              _ ->
                %{status: :warning, message: "Alert Store stats unavailable", details: "Service started but stats not ready"}
            end
          rescue
            _error ->
              %{status: :ok, message: "Alert Store operational", details: "Service running (stats method unavailable)"}
          end
        {:error, reason} ->
          %{status: :warning, message: "Alert Store startup needed", details: reason}
      end
    rescue
      error ->
        %{status: :error, message: "Alert Store test failed", details: "#{inspect(error)}"}
    end
  end
  
  defp test_agent_router do
    try do
      case DashboardGen.AgentRouter.classify_query_intent("test query") do
        intent when is_map(intent) ->
          %{status: :ok, message: "Agent Router operational", details: "Intent: #{intent.primary_intent}"}
        _ ->
          %{status: :error, message: "Agent Router failed", details: "Classification test failed"}
      end
    rescue
      error ->
        %{status: :error, message: "Agent Router test failed", details: "#{inspect(error)}"}
    end
  end
  
  defp test_content_tagging do
    test_content = %{title: "Test", text: "Test content", source: "test"}
    
    try do
      case DashboardGen.AgentTagging.tag_content(test_content) do
        %{tags: _tags} ->
          %{status: :ok, message: "Content Tagging operational", details: "Tagging test passed"}
        _ ->
          %{status: :error, message: "Content Tagging failed", details: "Tagging test failed"}
      end
    rescue
      error ->
        %{status: :error, message: "Content Tagging test failed", details: "#{inspect(error)}"}
    end
  end
  
  defp test_local_inference do
    try do
      case DashboardGen.LocalInference.get_performance_metrics() do
        metrics when is_map(metrics) ->
          %{status: :ok, message: "Local Inference configured", details: "Local available: #{metrics.local_available}"}
        _ ->
          %{status: :warning, message: "Local Inference not configured", details: "Check Ollama installation"}
      end
    rescue
      error ->
        %{status: :warning, message: "Local Inference not configured", details: "#{inspect(error)}"}
    end
  end
  
  defp test_prompt_drift do
    try do
      case DashboardGen.PromptDriftDetector.get_drift_analysis() do
        analysis when is_map(analysis) ->
          %{status: :ok, message: "Prompt Drift Detector operational", details: "Baseline: #{analysis.baseline_established}"}
        _ ->
          %{status: :warning, message: "Prompt Drift Detector not running", details: "Check if GenServer is started"}
      end
    rescue
      error ->
        %{status: :warning, message: "Prompt Drift Detector not configured", details: "#{inspect(error)}"}
    end
  end
  
  defp test_agent_coordinator do
    try do
      case DashboardGen.AgentCoordinator.list_workflows() do
        workflows when is_list(workflows) ->
          %{status: :ok, message: "Agent Coordinator operational", details: "#{length(workflows)} workflows available"}
        _ ->
          %{status: :warning, message: "Agent Coordinator not running", details: "Check if GenServer is started"}
      end
    rescue
      error ->
        %{status: :warning, message: "Agent Coordinator not configured", details: "#{inspect(error)}"}
    end
  end
  
  defp format_health_status(health) do
    """
    <div class="space-y-4">
      <div class="flex items-center gap-2">
        <span class="text-2xl">#{status_emoji(health.overall_status)}</span>
        <span class="font-semibold">Overall Status: #{String.upcase(to_string(health.overall_status))}</span>
      </div>
      
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <strong>Uptime:</strong> #{format_uptime(health.uptime_seconds)}
        </div>
        <div>
          <strong>Success Rate:</strong> #{Float.round(health.success_rate * 100, 1)}%
        </div>
        <div>
          <strong>Avg Response:</strong> #{Float.round(health.average_response_time, 1)}ms
        </div>
        <div>
          <strong>Last Check:</strong> #{format_datetime(health.last_check)}
        </div>
      </div>
      
      #{if health.system_metrics != %{} do
        format_system_metrics(health.system_metrics)
      else
        ""
      end}
      
      #{if length(health.recent_errors) > 0 do
        format_recent_errors(health.recent_errors)
      else
        "<div class=\"text-green-600 text-sm mt-4\">✅ No recent errors</div>"
      end}
    </div>
    """
  end
  
  defp format_recent_alerts(alerts) do
    if length(alerts) == 0 do
      """
      <div class="text-center py-8 text-gray-500">
        <div class="text-4xl mb-2">📭</div>
        <div>No recent alerts</div>
      </div>
      """
    else
      alert_items = Enum.map(alerts, fn alert ->
        """
        <div class="border-l-4 #{severity_border_color(alert.severity)} bg-gray-50 p-3 mb-3">
          <div class="flex items-center justify-between mb-1">
            <span class="font-semibold text-sm">#{alert.title}</span>
            <span class="text-xs text-gray-500">#{format_datetime(alert.timestamp)}</span>
          </div>
          <div class="text-xs text-gray-600">#{String.slice(alert.message, 0, 100)}#{if String.length(alert.message) > 100, do: "...", else: ""}</div>
          <div class="flex items-center gap-2 mt-2">
            <span class="text-xs px-2 py-1 rounded #{severity_bg_color(alert.severity)}">#{String.upcase(to_string(alert.severity))}</span>
            <span class="text-xs text-gray-500">Type: #{alert.type}</span>
          </div>
        </div>
        """
      end) |> Enum.join("")
      
      """
      <div class="max-h-96 overflow-y-auto">
        #{alert_items}
      </div>
      """
    end
  end
  
  defp format_test_loading do
    """
    <div class="text-center py-8">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mb-4"></div>
      <div class="text-gray-600">Testing all agent systems...</div>
      <div class="text-sm text-gray-500 mt-2">This may take a few seconds</div>
    </div>
    """
  end
  
  defp format_test_results(results) do
    overall_status = Map.get(results, :overall_status, :unknown)
    
    status_summary = case overall_status do
      :all_passed -> 
        """
        <div class="text-center mb-6">
          <div class="text-4xl mb-2">✅</div>
          <div class="text-lg font-semibold text-green-600">All Tests Passed</div>
        </div>
        """
      :some_failed ->
        """
        <div class="text-center mb-6">
          <div class="text-4xl mb-2">⚠️</div>
          <div class="text-lg font-semibold text-yellow-600">Some Tests Failed</div>
        </div>
        """
      :error ->
        """
        <div class="text-center mb-6">
          <div class="text-4xl mb-2">❌</div>
          <div class="text-lg font-semibold text-red-600">Test Execution Error</div>
          <div class="text-sm text-gray-600 mt-2">#{Map.get(results, :error, "Unknown error")}</div>
        </div>
        """
    end
    
    if overall_status == :error do
      status_summary
    else
      test_items = results
      |> Map.delete(:overall_status)
      |> Enum.map(fn {component, result} ->
        status_icon = case result.status do
          :ok -> "✅"
          :warning -> "⚠️"
          :error -> "❌"
        end
        
        """
        <div class="border rounded p-3 mb-2 #{result_bg_color(result.status)}">
          <div class="flex items-center justify-between mb-1">
            <span class="font-semibold">#{status_icon} #{String.capitalize(to_string(component))}</span>
            <span class="text-xs px-2 py-1 rounded #{result_badge_color(result.status)}">#{String.upcase(to_string(result.status))}</span>
          </div>
          <div class="text-sm text-gray-600">#{result.message}</div>
          <div class="text-xs text-gray-500 mt-1">#{result.details}</div>
        </div>
        """
      end) |> Enum.join("")
      
      """
      #{status_summary}
      <div class="space-y-2 max-h-80 overflow-y-auto">
        #{test_items}
      </div>
      """
    end
  end
  
  defp format_error_message(component_name, reason) do
    """
    <div class="text-center py-8">
      <div class="text-4xl mb-4">⚠️</div>
      <div class="text-lg font-semibold text-orange-600 mb-2">#{component_name} Not Available</div>
      <div class="text-sm text-gray-600 mb-4">The #{component_name} service needs to be started.</div>
      <div class="bg-orange-50 border border-orange-200 rounded p-4 text-left">
        <div class="font-semibold text-orange-800 mb-2">Quick Fix:</div>
        <div class="text-sm text-orange-700 font-mono bg-orange-100 p-2 rounded">
          # In IEx console:<br/>
          DashboardGen.#{String.replace(component_name, " ", "")}.start_link([])
        </div>
        <div class="text-xs text-orange-600 mt-2">Or click the button again - the system will auto-start the service.</div>
      </div>
      <div class="text-xs text-gray-500 mt-4">Error: #{String.slice(to_string(reason), 0, 100)}</div>
    </div>
    """
  end
  
  # Helper Functions
  
  defp extract_chart_data(content) do
    case String.split(content, "[CHART_DATA]:", parts: 2) do
      [analysis, chart_json] ->
        case Jason.decode(String.trim(chart_json)) do
          {:ok, chart_data} -> {String.trim(analysis), chart_data}
          _ -> {content, nil}
        end
      [_] -> {content, nil}
    end
  rescue
    _ -> {content, nil}
  end
  
  defp format_message_time(datetime) do
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
  
  defp status_emoji(status) do
    case status do
      :healthy -> "✅"
      :warning -> "⚠️"
      :critical -> "❌"
      _ -> "❓"
    end
  end
  
  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end
  
  defp format_datetime(datetime) do
    case datetime do
      %DateTime{} ->
        datetime
        |> DateTime.to_string()
        |> String.slice(0, 19)
        |> String.replace("T", " ")
      _ -> "Unknown"
    end
  end
  
  defp severity_border_color(severity) do
    case severity do
      :critical -> "border-red-500"
      :high -> "border-orange-500"
      :medium -> "border-yellow-500"
      :info -> "border-blue-500"
      _ -> "border-gray-500"
    end
  end
  
  defp severity_bg_color(severity) do
    case severity do
      :critical -> "bg-red-100 text-red-800"
      :high -> "bg-orange-100 text-orange-800"
      :medium -> "bg-yellow-100 text-yellow-800"
      :info -> "bg-blue-100 text-blue-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
  
  defp result_bg_color(status) do
    case status do
      :ok -> "bg-green-50 border-green-200"
      :warning -> "bg-yellow-50 border-yellow-200"
      :error -> "bg-red-50 border-red-200"
    end
  end
  
  defp result_badge_color(status) do
    case status do
      :ok -> "bg-green-100 text-green-800"
      :warning -> "bg-yellow-100 text-yellow-800"
      :error -> "bg-red-100 text-red-800"
    end
  end
  
  defp format_system_metrics(metrics) do
    """
    <div class="mt-4">
      <h4 class="font-semibold mb-2">System Metrics</h4>
      <div class="text-sm space-y-1">
        #{if Map.has_key?(metrics, :memory_usage) do
          "<div>Memory Usage: #{Float.round(metrics.memory_usage * 100, 1)}%</div>"
        else
          ""
        end}
        #{if Map.has_key?(metrics, :cpu_usage) do
          "<div>CPU Usage: #{Float.round(metrics.cpu_usage * 100, 1)}%</div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end
  
  defp format_recent_errors(errors) do
    error_items = Enum.take(errors, 3)
    |> Enum.map(fn error ->
      "<div class=\"text-xs text-red-600\">#{error.type}: #{String.slice(to_string(error.error), 0, 50)}...</div>"
    end)
    |> Enum.join("")
    
    """
    <div class="mt-4">
      <h4 class="font-semibold mb-2 text-red-600">Recent Errors</h4>
      #{error_items}
    </div>
    """
  end
end
