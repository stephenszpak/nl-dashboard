defmodule DashboardGen.CodexClient do
  @moduledoc """
  Backward compatibility alias for DashboardGen.OpenAIClient.
  This module will be deprecated in favor of OpenAIClient.
  """

  alias DashboardGen.OpenAIClient

  @deprecated "Use DashboardGen.OpenAIClient.ask/2 instead"
  defdelegate ask(prompt), to: OpenAIClient

  @deprecated "Use DashboardGen.OpenAIClient.ask/2 instead"
  defdelegate ask(prompt, opts), to: OpenAIClient
end