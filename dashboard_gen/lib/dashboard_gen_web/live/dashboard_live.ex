defmodule DashboardGenWeb.DashboardLive do
  use Phoenix.LiveView, layout: {DashboardGenWeb.Layouts, :dashboard}
  use DashboardGenWeb, :html
  import DashboardGenWeb.CoreComponents
  alias DashboardGen.GPTClient
  alias DashboardGen.Codex.Summarizer
  alias DashboardGen.Codex.Explainer
  alias DashboardGen.Uploads
  alias DashboardGen.AnomalyDetector
  alias DashboardGen.CompetitivePrompts
  alias DashboardGen.{Insights, CodexClient, Analytics}
  alias VegaLite

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Dashboard",
       prompt: "",
       chart_spec: nil,
       loading: false,
       collapsed: false,
       summary: nil,
       explanation: nil,
       alerts: nil,
       show_prompt_categories: false,
       prompt_categories: CompetitivePrompts.get_categories(),
       smart_suggestions: CompetitivePrompts.get_smart_suggestions(),
       competitive_analysis: nil,
       analytics_charts: [],
       mode: "competitive_intelligence" # "data_analysis" or "competitive_intelligence"
     )}
  end

  @impl true
  def handle_event("generate", %{"prompt" => prompt}, socket) do
    # Always use competitive intelligence for now
    send(self(), {:analyze_competitive, prompt})
    
    {:noreply,
     assign(socket,
       prompt: prompt,
       loading: true,
       competitive_analysis: nil,
       analytics_charts: [],
       chart_spec: nil,
       summary: nil,
       explanation: nil,
       alerts: nil
     )}
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
    
    # Debug logging to ensure prompt is being captured
    IO.inspect(prompt, label: "Original prompt")
    IO.inspect(contextualized_prompt, label: "Contextualized prompt")
    
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
  def handle_info({:analyze_competitive, prompt}, socket) do
    case analyze_competitive_intelligence(prompt) do
      {:ok, analysis} ->
        # If this is an analytics question, also generate charts
        charts = if is_analytics_question?(prompt) do
          generate_analytics_charts()
        else
          []
        end
        
        {:noreply,
         assign(socket,
           competitive_analysis: analysis,
           analytics_charts: charts,
           loading: false
         )}
      
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Analysis failed: #{reason}")
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
  
  defp generate_analytics_charts do
    # Get analytics summary data
    summary = Analytics.get_analytics_summary(7)
    
    [
      generate_top_pages_chart(summary.top_pages),
      generate_geography_chart(summary.geographic_breakdown),
      generate_events_chart(summary.top_events)
    ]
  end
  
  defp generate_top_pages_chart(top_pages) do
    %{
      id: "top-pages-chart",
      title: "📊 Top Pages",
      type: "bar",
      data: %{
        labels: Enum.map(top_pages, & &1.page),
        datasets: [%{
          label: "Page Views",
          data: Enum.map(top_pages, & &1.views),
          backgroundColor: "rgba(59, 130, 246, 0.8)",
          borderColor: "rgba(59, 130, 246, 1)",
          borderWidth: 1
        }]
      },
      options: %{
        responsive: true,
        plugins: %{
          legend: %{display: false}
        },
        scales: %{
          y: %{beginAtZero: true}
        }
      }
    }
  end
  
  defp generate_geography_chart(geographic_breakdown) do
    %{
      id: "geography-chart", 
      title: "🌍 Geographic Distribution",
      type: "doughnut",
      data: %{
        labels: Enum.map(geographic_breakdown, & &1.country),
        datasets: [%{
          data: Enum.map(geographic_breakdown, & &1.visitors),
          backgroundColor: [
            "rgba(59, 130, 246, 0.8)",
            "rgba(16, 185, 129, 0.8)", 
            "rgba(245, 158, 11, 0.8)",
            "rgba(239, 68, 68, 0.8)",
            "rgba(139, 92, 246, 0.8)",
            "rgba(236, 72, 153, 0.8)",
            "rgba(34, 197, 94, 0.8)",
            "rgba(251, 146, 60, 0.8)",
            "rgba(168, 85, 247, 0.8)"
          ]
        }]
      },
      options: %{
        responsive: true,
        plugins: %{
          legend: %{
            position: "bottom",
            labels: %{
              boxWidth: 12,
              font: %{size: 11}
            }
          }
        }
      }
    }
  end
  
  defp generate_events_chart(top_events) do
    %{
      id: "events-chart",
      title: "📈 User Events", 
      type: "line",
      data: %{
        labels: Enum.map(top_events, & &1.event),
        datasets: [%{
          label: "Event Count",
          data: Enum.map(top_events, & &1.count),
          borderColor: "rgba(16, 185, 129, 1)",
          backgroundColor: "rgba(16, 185, 129, 0.1)",
          borderWidth: 2,
          fill: true,
          tension: 0.4
        }]
      },
      options: %{
        responsive: true,
        plugins: %{
          legend: %{display: false}
        },
        scales: %{
          y: %{beginAtZero: true}
        }
      }
    }
  end
end
