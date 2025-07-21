defmodule DashboardGenWeb.LiveHelpers do
  @moduledoc false

  @doc """
  Wraps `Phoenix.LiveView.put_session/3` for compatibility with
  older LiveView versions.
  If the function is unavailable, returns the socket unchanged.
  """
  def maybe_put_session(socket, key, value) do
    if function_exported?(Phoenix.LiveView, :put_session, 3) do
      apply(Phoenix.LiveView, :put_session, [socket, key, value])
    else
      # Fallback: Send session update to parent process for older LiveView versions
      send(self(), {:put_session, key, value})
      socket
    end
  end
end
