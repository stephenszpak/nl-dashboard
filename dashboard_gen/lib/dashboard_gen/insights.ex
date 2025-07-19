defmodule DashboardGen.Insights do
  @moduledoc """
  Provides helper functions for working with competitor insights.
  """

  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Scrapers.Insight

  @doc """
  Returns insights grouped by company. Each company will include the
  most recent `limit` press releases based on the `inserted_at` timestamp
  of the Insight record.
  """
  def list_recent_insights_by_company(limit \\ 10) do
    Insight
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
    |> Enum.flat_map(fn insight ->
      Enum.map(insight.data, fn item ->
        %{
          company: item["company"] || insight.source,
          title: item["title"],
          url: item["url"],
          date: item["date"],
          summary: item["summary"],
          inserted_at: insight.inserted_at
        }
      end)
    end)
    |> Enum.group_by(& &1.company)
    |> Enum.map(fn {company, items} ->
      sorted = Enum.sort_by(items, &(&1.inserted_at || ~N[1970-01-01 00:00:00]), {:desc, NaiveDateTime})
      {company, Enum.take(sorted, limit)}
    end)
  end
end
