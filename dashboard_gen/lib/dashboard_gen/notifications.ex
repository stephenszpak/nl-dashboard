defmodule DashboardGen.Notifications do
  @moduledoc """
  Notification system for agent triggers and alerts.
  
  Handles various notification channels and formats alert messages
  for different types of agent-detected events.
  """
  
  require Logger
  
  @doc """
  Send trigger alert notification
  """
  def send_trigger_alert(trigger_data, analysis) do
    Logger.info("Sending trigger alert: #{trigger_data.type}")
    
    # Format the alert message
    message = format_alert_message(trigger_data, analysis)
    
    # Send via multiple channels
    send_console_alert(message)
    send_dashboard_alert(trigger_data, message)
    
    # Could add: email, Slack, webhook notifications
    # send_email_alert(message)
    # send_slack_alert(message) 
    
    :ok
  end
  
  defp format_alert_message(%{type: :analytics_spike} = data, analysis) do
    """
    🚨 ANALYTICS SPIKE DETECTED
    
    📊 Metric: #{String.capitalize(String.replace(data.metric, "_", " "))}
    📈 Change: #{data.current} (#{if data.change_percent >= 0, do: "+", else: ""}#{Float.round(data.change_percent, 1)}% from baseline)
    ⏰ Time: #{DateTime.to_string(DateTime.utc_now())}
    
    🧠 AI Analysis:
    #{analysis}
    
    💡 Recommended Actions:
    - Monitor trend continuation
    - Investigate traffic sources if applicable
    - Consider scaling infrastructure if needed
    """
  end
  
  defp format_alert_message(%{type: :competitor_spike} = data, analysis) do
    recent_content = Enum.join(data.recent_titles, "\n• ")
    
    """
    🎯 COMPETITOR ACTIVITY SPIKE DETECTED
    
    🏢 Company: #{data.company}
    📊 Activity: #{String.capitalize(String.replace(data.metric, "_", " "))}
    📈 Current: #{data.current} (vs baseline #{data.baseline})
    ⏰ Time: #{DateTime.to_string(DateTime.utc_now())}
    
    📰 Recent Content:
    • #{recent_content}
    
    🧠 AI Analysis:
    #{analysis}
    
    🎯 Strategic Response:
    - Monitor competitor strategy changes
    - Assess impact on market positioning
    - Consider counter-moves if necessary
    """
  end
  
  defp format_alert_message(%{type: :market_trend} = data, analysis) do
    """
    📈 MARKET TREND CHANGE DETECTED
    
    🏷️ Topic: #{data.topic}
    📊 Direction: #{data.change}
    ⚡ Significance: #{data.significance}
    ⏰ Time: #{DateTime.to_string(DateTime.utc_now())}
    
    🌍 Context: #{data.context}
    
    🧠 AI Analysis:
    #{analysis}
    
    🎯 Strategic Implications:
    - Evaluate positioning alignment
    - Consider product/service adjustments
    - Monitor client sentiment changes
    """
  end
  
  defp send_console_alert(message) do
    Logger.info("=== AGENT ALERT ===")
    Logger.info(message)
    Logger.info("==================")
  end
  
  defp send_dashboard_alert(trigger_data, message) do
    # Store alert for dashboard display
    alert = %{
      id: generate_alert_id(),
      type: trigger_data.type,
      severity: determine_severity(trigger_data),
      title: generate_alert_title(trigger_data),
      message: message,
      timestamp: DateTime.utc_now(),
      acknowledged: false,
      metadata: trigger_data
    }
    
    # Store in GenServer or ETS table for real-time dashboard updates
    DashboardGen.AlertStore.store_alert(alert)
    
    # Could broadcast to LiveView for real-time updates
    # Phoenix.PubSub.broadcast(DashboardGen.PubSub, "alerts", {:new_alert, alert})
  end
  
  defp determine_severity(%{type: :analytics_spike, change_percent: change}) when change > 500, do: :critical
  defp determine_severity(%{type: :analytics_spike, change_percent: change}) when change > 200, do: :high
  defp determine_severity(%{type: :analytics_spike}), do: :medium
  defp determine_severity(%{type: :competitor_spike}), do: :medium
  defp determine_severity(%{type: :market_trend, significance: sig}) when sig > 0.7, do: :high
  defp determine_severity(%{type: :market_trend}), do: :medium
  
  defp generate_alert_title(%{type: :analytics_spike, metric: metric}) do
    "Analytics Spike: #{String.capitalize(String.replace(metric, "_", " "))}"
  end
  defp generate_alert_title(%{type: :competitor_spike, company: company}) do
    "Competitor Activity: #{company}"
  end
  defp generate_alert_title(%{type: :market_trend, topic: topic}) do
    "Market Trend: #{topic}"
  end
  
  defp generate_alert_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end