defmodule DashboardGen.Insights do
  @moduledoc """
  Provides helper functions for working with competitor insights.
  """

  import Ecto.Query, warn: false
  alias DashboardGen.Repo
  alias DashboardGen.Scrapers.Insight
  alias DashboardGen.Insights.TopicSummary
  alias DashboardGen.CodexClient

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

  @doc """
  Generate or fetch a cached summary of common topics for the given company.
  A new summary will be requested from OpenAI if none exists within the
  last 24 hours.
  """
  def generate_topic_summary(company) when is_binary(company) do
    case get_recent_summary(company) do
      %TopicSummary{summary: summary} -> {:ok, summary}
      nil -> do_generate_summary(company)
    end
  end

  defp do_generate_summary(company) do
    with insights when insights != [] <- list_company_insights(company, 90),
         text <-
           insights
           |> Enum.flat_map(fn i -> [i.title, i.content] end)
           |> Enum.reject(&is_nil/1)
           |> Enum.join("\n"),
         prompt <-
           """
           You are analyzing a list of recent press releases from #{company}. Summarize the most common topics or themes they focus on.
           #{text}
           """
           |> String.trim(),
         {:ok, summary} <- CodexClient.ask(prompt),
         {:ok, _rec} <-
           %TopicSummary{}
           |> TopicSummary.changeset(%{company: company, summary: summary})
           |> Repo.insert() do
      {:ok, summary}
    else
      [] -> {:error, :no_insights}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_recent_summary(company) do
    from(s in TopicSummary,
      where: s.company == ^company and s.inserted_at > ago(1, "day"),
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp list_company_insights(company, days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86_400, :second)

    Insight
    |> where([i], i.inserted_at >= ^cutoff)
    |> Repo.all()
    |> Enum.flat_map(fn insight ->
      Enum.map(insight.data, fn item ->
        %{
          company: item["company"] || insight.source,
          title: item["title"],
          content: item["content"] || item["summary"],
          inserted_at: insight.inserted_at
        }
      end)
    end)
    |> Enum.filter(&(&1.company == company))
  end
end
