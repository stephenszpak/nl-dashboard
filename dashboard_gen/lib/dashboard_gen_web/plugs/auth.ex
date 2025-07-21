defmodule DashboardGenWeb.Plugs.Auth do
  @moduledoc """
  A collection of simple authentication plugs used throughout the router.

  It can be invoked with `plug DashboardGenWeb.Plugs.Auth, :fetch_current_user`
  or `plug DashboardGenWeb.Plugs.Auth, :require_authenticated`.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias DashboardGen.Accounts

  @doc """
  Callback required by `Plug` behaviour.
  """
  def init(action), do: action

  @doc """
  Dispatches to the appropriate plug based on the action.
  """
  def call(conn, action) do
    case action do
      :fetch_current_user -> fetch_current_user(conn, [])
      :require_authenticated -> require_authenticated(conn, [])
      _ -> conn
    end
  end

  @doc """
  Fetches the currently logged in user and assigns it to the connection.
  Uses session token for authentication.
  """
  def fetch_current_user(conn, _opts) do
    user = with token when is_binary(token) <- get_session(conn, :session_token),
                session when not is_nil(session) <- Accounts.get_valid_session(token) do
             session.user
           else
             _ -> nil
           end
    assign(conn, :current_user, user)
  end

  @doc """
  Halts the request unless a user is assigned.
  """
  def require_authenticated(%{assigns: %{current_user: nil}} = conn, _opts) do
    conn
    |> redirect(to: "/login")
    |> halt()
  end

  def require_authenticated(conn, _opts), do: conn
end
