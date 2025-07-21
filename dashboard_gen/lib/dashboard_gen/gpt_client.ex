defmodule DashboardGen.GPTClient do
  @moduledoc """
  Backward compatibility alias for DashboardGen.OpenAIClient chart functionality.
  This module will be deprecated in favor of OpenAIClient.
  """

  alias DashboardGen.OpenAIClient

  @deprecated "Use DashboardGen.OpenAIClient.get_chart_spec/3 instead"
  defdelegate get_chart_spec(prompt, headers), to: OpenAIClient

  @deprecated "Use DashboardGen.OpenAIClient.get_chart_spec/3 instead"
  def get_chart_spec(prompt, headers, opts), do: OpenAIClient.get_chart_spec(prompt, headers, opts)

  @deprecated "Use DashboardGen.OpenAIClient directly instead"
  defdelegate default_system_prompt(headers), to: OpenAIClient, as: :chart_system_prompt

  @deprecated "Use DashboardGen.OpenAIClient directly instead"  
  defdelegate extract_json_block(content), to: OpenAIClient
end