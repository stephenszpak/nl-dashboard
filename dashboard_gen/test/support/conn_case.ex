defmodule DashboardGenWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      alias DashboardGenWeb.Router.Helpers, as: Routes

      @endpoint DashboardGenWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DashboardGen.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(DashboardGen.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
