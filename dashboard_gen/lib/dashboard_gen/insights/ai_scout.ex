defmodule DashboardGen.Insights.AIScout do
  @moduledoc """
  Uses OpenAI to generate recent competitor insights (press releases, news, social highlights)
  and stores them in the existing insights table, so the rest of the app can consume them
  without relying on external scrapers.

  Note: This relies on the model's knowledge and may not reflect real-time browsing.
  It requests structured JSON and normalizes it to the expected schema.
  """

  alias DashboardGen.Repo
  alias DashboardGen.OpenAIClient
  alias DashboardGen.Scrapers.Insight
  alias DashboardGen.AI

  require Logger
  alias Phoenix.PubSub

  @topic "ai_insights_status"

  @default_items_per_company 5
  @default_days_back 14

  @doc """
  Fetch insights for the configured companies and store as a single insights record.

  Options:
  - companies: list of company names (defaults to configured companies)
  - days_back: how recent insights should be (default 14)
  - items_per_company: max items per company (default 5)
  - tags: optional list of focus tags/topics
  """
  def fetch_and_store(opts \\ []) do
    companies =
      Keyword.get(opts, :companies) ||
        (Application.get_env(:dashboard_gen, :data_collectors)[:companies] || [])

    if Enum.empty?(companies) do
      {:error, :no_companies}
    else
      days_back = Keyword.get(opts, :days_back, @default_days_back)
      max_items = Keyword.get(opts, :items_per_company, @default_items_per_company)
      tags = Keyword.get(opts, :tags, [])

      prompt = build_prompt(companies, days_back, max_items, tags)
      system = system_prompt()

      broadcast(%{status: :started, companies: companies, days_back: days_back})
      broadcast(%{status: :requesting})

      with {:ok, %{"insights" => items}} <- OpenAIClient.ask_for_json(prompt, system),
           _ <- broadcast(%{status: :received, items: length(items)}),
           normalized when is_list(normalized) <- Enum.map(items, &normalize_item/1),
           _ <- broadcast(%{status: :inserting, items: length(normalized)}),
           {:ok, _rec} <-
             %Insight{}
             |> Insight.changeset(%{source: "openai_ai_scout", data: normalized})
             |> Repo.insert() do
        broadcast(%{status: :completed, items: length(normalized)})
        {:ok, length(normalized)}
      else
        {:error, reason} ->
          Logger.error("AIScout failed: #{inspect(reason)}")
          broadcast(%{status: :error, error: inspect(reason)})
          {:error, reason}
        other ->
          Logger.error("AIScout unexpected response: #{inspect(other)}")
          broadcast(%{status: :error, error: inspect(other)})
          {:error, :invalid_response}
      end
    end
  end

  @doc """
  AI-first collection: fetch snapshot, events, and insights in one JSON per company
  and store into ai_* tables.
  """
  def fetch_and_store_v2(opts \\ []) do
    companies =
      Keyword.get(opts, :companies) ||
        (Application.get_env(:dashboard_gen, :data_collectors)[:companies] || [])

    days_back = Keyword.get(opts, :days_back, @default_days_back)
    max_items = Keyword.get(opts, :items_per_company, @default_items_per_company)
    tags = Keyword.get(opts, :tags, [])
    cutoff = Date.utc_today() |> Date.add(-days_back)

    broadcast(%{status: :started_v2, companies: companies, days_back: days_back})

    Enum.each(companies, fn company ->
      prompt = v2_prompt(company, days_back, max_items, tags)
      system = v2_system_prompt()

      broadcast(%{status: :requesting, company: company})
      case OpenAIClient.ask_for_json(prompt, system) do
        {:ok, %{"snapshot" => snap, "events" => events, "insights" => insights, "topics" => topics}} ->
          # Insert snapshot
          _ = insert_snapshot(company, snap, cutoff)
          # Insert events
          _ = Enum.map(events || [], &insert_event(company, &1, cutoff))
          # Insert insights
          _ = Enum.map(insights || [], &insert_insight(company, &1, cutoff))
          # Ensure topics
          _ = Enum.map(topics || [], &ensure_topic/1)
          broadcast(%{status: :completed_company, company: company})
        other ->
          Logger.error("AIScout v2 invalid response for #{company}: #{inspect(other)}")
          broadcast(%{status: :error, company: company, error: inspect(other)})
      end
    end)

    broadcast(%{status: :completed_v2})
    :ok
  end

  defp insert_snapshot(company, snap, cutoff) when is_map(snap) do
    attrs = %{
      company: company,
      period: snap["period"],
      summary: snap["summary"],
      key_metrics: snap["key_metrics"] || %{},
      top_risks: snap["top_risks"] || %{},
      top_opportunities: snap["top_opportunities"] || %{},
      period_start: parse_date(snap["period_start"]) ,
      period_end: parse_date(snap["period_end"]) ,
      provenance: snap["provenance"] || %{},
      evidence: snap["evidence"] || %{},
      raw_json: snap
    }
    # Only store if period intersects cutoff window
    within_window? =
      case {attrs.period_start, attrs.period_end} do
        {nil, nil} -> true
        {_, nil} -> true
        {nil, _} -> true
        {ps, pe} -> Date.compare(pe, cutoff) != :lt and Date.compare(ps, Date.utc_today()) != :gt
      end

    if within_window?, do: AI.create_snapshot(attrs), else: {:ok, :skipped_old_snapshot}
  end

  defp insert_event(company, ev, cutoff) when is_map(ev) do
    attrs = %{
      company: company,
      event_type: ev["event_type"],
      title: ev["title"] || "",
      description: ev["description"],
      occurred_on: parse_date(ev["occurred_on"]),
      time_start: parse_date(ev["time_start"]),
      time_end: parse_date(ev["time_end"]),
      tags: ev["tags"] || [],
      entities: ev["entities"] || [],
      sentiment_score: ev["sentiment_score"],
      impact_score: ev["impact_score"],
      provenance: ev["provenance"] || %{},
      evidence: ev["evidence"] || %{},
      raw_json: ev
    }
    # Drop events older than cutoff when date available
    cond do
      is_nil(attrs.occurred_on) -> AI.create_event(attrs)
      Date.compare(attrs.occurred_on, cutoff) in [:gt, :eq] -> AI.create_event(attrs)
      true -> {:ok, :skipped_old_event}
    end
  end

  defp insert_insight(company, ins, cutoff) when is_map(ins) do
    attrs = %{
      company: company,
      category: ins["category"],
      title: ins["title"] || "",
      summary: ins["summary"],
      detail: ins["detail"],
      period_start: parse_date(ins["period_start"]),
      period_end: parse_date(ins["period_end"]),
      freshness_days: ins["freshness_days"],
      tags: ins["tags"] || [],
      entities: ins["entities"] || [],
      sentiment_score: ins["sentiment_score"],
      impact_score: ins["impact_score"],
      provenance: ins["provenance"] || %{},
      evidence: ins["evidence"] || %{},
      raw_json: ins
    }
    # Keep only insights that reference recent period or declare freshness within window
    recent_period? =
      case {attrs.period_start, attrs.period_end} do
        {nil, nil} -> true
        {_, nil} -> true
        {nil, _} -> Date.compare(attrs.period_end, cutoff) != :lt
        {ps, pe} -> Date.compare(pe, cutoff) != :lt and Date.compare(ps, Date.utc_today()) != :gt
      end

    fresh? = is_integer(attrs.freshness_days) and attrs.freshness_days <= Date.diff(Date.utc_today(), cutoff)

    if recent_period? or fresh?, do: AI.create_insight(attrs), else: {:ok, :skipped_old_insight}
  end

  defp ensure_topic(topic) when is_binary(topic) do
    AI.get_or_create_topic(topic)
  end
  defp ensure_topic(%{"name" => name} = t) do
    AI.get_or_create_topic(name, %{description: t["description"], aliases: t["aliases"] || []})
  end

  defp parse_date(nil), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp v2_system_prompt do
    """
    You are a research assistant. Respond ONLY with valid JSON per the schema.
    Include provenance (model, confidence, generated_at ISO8601) and evidence when possible.
    """
  end

  defp v2_prompt(company, days_back, max_items, tags) do
    tags_text = if tags == [], do: "none", else: Enum.join(tags, ", ")
    today = Date.utc_today() |> Date.to_iso8601()
    cutoff = Date.utc_today() |> Date.add(-days_back) |> Date.to_iso8601()
    """
    For company: #{company}
    Timeframe: last #{days_back} days
    Focus tags: #{tags_text}
    Max items per section: #{max_items}
    Today is #{today}. Only include items on or after #{cutoff}. If you are not reasonably confident an item occurred on or after #{cutoff}, omit it.
    Do not fabricate dates. If there is insufficient recent information, return empty arrays.

    Return JSON with this shape:
    {
      "snapshot": {
        "period": "YYYY-MM",
        "summary": "string",
        "key_metrics": {"kpi": value, ...},
        "top_risks": [{"title": "", "detail": ""}],
        "top_opportunities": [{"title": "", "detail": ""}],
        "period_start": "YYYY-MM-DD",
        "period_end": "YYYY-MM-DD",
        "provenance": {"source_type": "model_knowledge", "model": "gpt-4o", "generated_at": "ISO", "confidence": 0.0},
        "evidence": []
      },
      "events": [
        {
          "event_type": "announcement|launch|partnership|leadership|funding|legal|esg|hiring|campaign",
          "title": "string",
          "description": "string",
          "occurred_on": "YYYY-MM-DD",
          "time_start": null,
          "time_end": null,
          "tags": ["..."],
          "entities": ["..."],
          "sentiment_score": 0.0,
          "impact_score": 0.0,
          "provenance": {"source_type": "model_knowledge", "model": "gpt-4o", "generated_at": "ISO", "confidence": 0.0},
          "evidence": []
        }
      ],
      "insights": [
        {
          "category": "overview|strategy|product|partnership|finance|esg|hiring|legal|marketing|risk|opportunity",
          "title": "string",
          "summary": "string",
          "detail": "string",
          "period_start": "YYYY-MM-DD",
          "period_end": "YYYY-MM-DD",
          "freshness_days": 0,
          "tags": ["..."],
          "entities": ["..."],
          "sentiment_score": 0.0,
          "impact_score": 0.0,
          "provenance": {"source_type": "model_knowledge", "model": "gpt-4o", "generated_at": "ISO", "confidence": 0.0},
          "evidence": []
        }
      ],
      "topics": ["..." or {"name": "string", "description": "string", "aliases": ["..."]}]
    }
    Respond with JSON only.
    """
  end

  @doc """
  Generate actionable recommendations for a company based on recent AI events/insights.
  Stores them in ai_insights with category "recommendation".
  """
  def generate_recommendations(company, days_back \\ 30) do
    recent_events = DashboardGen.AI.list_events_or_empty(company, days_back: days_back, limit: 50)
    context =
      recent_events
      |> Enum.map(fn ev -> "- [#{ev.occurred_on || "n/a"}] (#{ev.event_type || "event"}) #{ev.title}" end)
      |> Enum.join("\n")

    system = "You are a strategy assistant. Respond ONLY with valid JSON."
    prompt = """
    Company: #{company}
    Recent context (last #{days_back} days):
    #{context}

    Return JSON:
    {
      "recommendations": [
        {
          "title": "string",
          "summary": "string",
          "impact": 0.0,
          "urgency": "low|medium|high",
          "rationale": "string",
          "tags": ["..."]
        }
      ],
      "provenance": {"source_type": "model_knowledge", "model": "gpt-4o", "generated_at": "ISO", "confidence": 0.0}
    }
    JSON only.
    """

    case OpenAIClient.ask_for_json(prompt, system) do
      {:ok, %{"recommendations" => recos} = all} when is_list(recos) ->
        Enum.each(recos, fn rec ->
          _ = DashboardGen.AI.create_insight(%{
            company: company,
            category: "recommendation",
            title: rec["title"] || "Recommendation",
            summary: rec["summary"],
            detail: rec["rationale"],
            impact_score: rec["impact"],
            tags: rec["tags"] || [],
            provenance: all["provenance"] || %{},
            raw_json: rec
          })
        end)
        {:ok, length(recos)}
      other -> other
    end
  end

  defp system_prompt do
    """
    You are a research assistant returning ONLY JSON that matches the schema.
    You MUST include precise fields when known. Avoid generic/boilerplate content.
    If you don't know the source URL, set it to null.
    """
  end

  defp build_prompt(companies, days_back, max_items, tags) do
    companies_text = Enum.map(companies, &"- #{&1}") |> Enum.join("\n")
    tags_text =
      case tags do
        [] -> "none"
        list -> Enum.join(list, ", ")
      end

    """
    Research recent competitor insights for the following companies and return JSON only.
    Companies:
    #{companies_text}

    Timeframe: last #{days_back} days
    Focus tags: #{tags_text}
    Max items per company: #{max_items}

    JSON schema:
    {
      "insights": [
        {
          "company": "string",
          "title": "string",
          "summary": "string",
          "date": "YYYY-MM-DD",
          "source": "press_release|news|social_media",
          "url": "string or null"
        }
      ]
    }

    Rules:
    - Provide specific, concise titles and summaries.
    - Include the company field for each item.
    - Prefer items within the timeframe; if unsure, include only likely recent items.
    - Do not include commentary outside the JSON.
    """
  end

  defp normalize_item(item) when is_map(item) do
    %{
      "company" => item["company"],
      "title" => item["title"],
      "content" => item["summary"],
      "url" => item["url"],
      "date" => item["date"],
      "summary" => item["summary"],
      "source" => normalize_source(item["source"])
    }
  end

  defp normalize_source(src) do
    case src do
      s when is_binary(s) ->
        s
        |> String.downcase()
        |> case do
          "press" <> _ -> "press_release"
          "news" <> _ -> "news"
          "social" <> _ -> "social_media"
          other -> other
        end
      _ -> "news"
    end
  end

  defp broadcast(payload) do
    PubSub.broadcast(DashboardGen.PubSub, @topic, {:ai_insights_status, payload})
  end
end
