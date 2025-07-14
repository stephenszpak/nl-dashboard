defmodule DashboardGen.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias DashboardGen.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import DashboardGen.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DashboardGen.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(DashboardGen.Repo, {:shared, self()})
    end

    :ok
  end
end
