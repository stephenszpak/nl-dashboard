defmodule DashboardGenWeb.AuthHelpers do
  @moduledoc """
  Shared authentication helpers for LiveView modules.
  """
  
  alias DashboardGen.Accounts

  @doc """
  Gets the current user from session token.
  Returns user struct or nil if not found/invalid.
  """
  def get_current_user(session) do
    case Map.get(session, "session_token") do
      token when is_binary(token) ->
        case Accounts.get_valid_session(token) do
          %{user: user} -> user
          _ -> nil
        end
      _ -> nil
    end
  end

  @doc """
  Redirects to login path if user is nil.
  Used in mount/3 functions.
  """
  def require_authentication(socket, user) do
    if user do
      {:ok, socket |> Phoenix.Component.assign(:current_user, user)}
    else
      {:error, socket |> Phoenix.LiveView.redirect(to: "/login")}
    end
  end
end