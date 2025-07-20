defmodule DashboardGen.AutonomousAgent do
  @moduledoc """
  Autonomous GPT-powered agent for competitive intelligence analysis.
  
  This agent can:
  - Automatically scrape competitor data
  - Analyze trends and patterns
  - Generate insights and alerts
  - Make decisions about data collection priorities
  - Self-schedule follow-up actions
  """
  
  use GenServer
  require Logger
  
  alias DashboardGen.{Scrapers, Insights, GPTClient, CodexClient}
  alias DashboardGen.AutonomousAgent.{DecisionEngine, Memory}
  
  # Agent states
  @idle :idle
  @analyzing :analyzing
  @scraping :scraping
  @planning :planning
  
  defstruct [
    :state,
    :current_task,
    :memory,
    :last_analysis,
    :priorities,
    :scheduled_tasks
  ]
  
  ## Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc "Manually trigger agent analysis cycle"
  def analyze_now do
    GenServer.cast(__MODULE__, :analyze_now)
  end
  
  @doc "Get current agent status"
  def status do
    GenServer.call(__MODULE__, :status)
  end
  
  @doc "Ask agent a question about insights"
  def ask_question(question) when is_binary(question) do
    GenServer.call(__MODULE__, {:ask_question, question}, 30_000)
  end
  
  ## GenServer Callbacks
  
  @impl true
  def init(_opts) do
    # Schedule periodic analysis every 4 hours
    Process.send_after(self(), :periodic_analysis, :timer.hours(4))
    
    state = %__MODULE__{
      state: @idle,
      current_task: nil,
      memory: Memory.new(),
      last_analysis: nil,
      priorities: %{},
      scheduled_tasks: []
    }
    
    Logger.info("🤖 Autonomous Agent started")
    {:ok, state}
  end
  
  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      current_state: state.state,
      current_task: state.current_task,
      last_analysis: state.last_analysis,
      memory_size: Memory.size(state.memory),
      scheduled_tasks: length(state.scheduled_tasks)
    }
    {:reply, status, state}
  end
  
  @impl true
  def handle_call({:ask_question, question}, _from, state) do
    case answer_question(question, state) do
      {:ok, answer} -> {:reply, {:ok, answer}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast(:analyze_now, state) do
    send(self(), :perform_analysis)
    {:noreply, %{state | state: @planning}}
  end
  
  @impl true
  def handle_info(:periodic_analysis, state) do
    # Schedule next analysis
    Process.send_after(self(), :periodic_analysis, :timer.hours(4))
    
    # Trigger analysis if not busy
    if state.state == @idle do
      send(self(), :perform_analysis)
      {:noreply, %{state | state: @planning}}
    else
      Logger.info("🤖 Skipping analysis cycle - agent busy with #{state.state}")
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:perform_analysis, state) do
    Logger.info("🤖 Starting autonomous analysis cycle")
    
    case run_analysis_cycle(state) do
      {:ok, new_state} ->
        Logger.info("🤖 Analysis cycle completed successfully")
        {:noreply, %{new_state | state: @idle}}
        
      {:error, reason} ->
        Logger.error("🤖 Analysis cycle failed: #{inspect(reason)}")
        {:noreply, %{state | state: @idle}}
    end
  end
  
  ## Private Functions
  
  defp run_analysis_cycle(state) do
    with {:ok, insights} <- collect_recent_insights(),
         {:ok, analysis} <- analyze_insights(insights),
         {:ok, decisions} <- make_decisions(analysis, state.memory),
         {:ok, new_memory} <- update_memory(state.memory, analysis, decisions),
         {:ok, actions} <- execute_decisions(decisions) do
      
      new_state = %{state | 
        last_analysis: DateTime.utc_now(),
        memory: new_memory,
        scheduled_tasks: actions
      }
      
      {:ok, new_state}
    end
  end
  
  defp collect_recent_insights do
    try do
      insights = Insights.list_recent_insights_by_company(20)
      {:ok, insights}
    rescue
      e -> {:error, e}
    end
  end
  
  defp analyze_insights(insights) do
    # Flatten all insights into analyzable text
    all_content = 
      insights
      |> Enum.flat_map(fn {_company, data} ->
        (data.press_releases ++ data.social_media)
        |> Enum.map(&("#{&1.title} #{&1.content}"))
      end)
      |> Enum.join("\n")
    
    prompt = """
    You are an autonomous competitive intelligence agent. Analyze the following recent competitor activities and provide insights in JSON format:
    
    #{String.slice(all_content, 0, 4000)}
    
    Respond with JSON containing:
    {
      "trends": ["key trend 1", "key trend 2"],
      "opportunities": ["opportunity 1", "opportunity 2"], 
      "threats": ["threat 1", "threat 2"],
      "recommendations": ["action 1", "action 2"],
      "priority_companies": ["company1", "company2"],
      "confidence_score": 0.85
    }
    """
    
    case CodexClient.ask(prompt) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, analysis} -> {:ok, analysis}
          {:error, _} -> {:ok, %{"summary" => response}}
        end
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp make_decisions(analysis, memory) do
    decisions = DecisionEngine.evaluate(analysis, memory)
    {:ok, decisions}
  end
  
  defp update_memory(memory, analysis, decisions) do
    new_memory = 
      memory
      |> Memory.store_analysis(analysis)
      |> Memory.store_decisions(decisions)
      |> Memory.cleanup_old_data()
    
    {:ok, new_memory}
  end
  
  defp execute_decisions(decisions) do
    actions = 
      Enum.map(decisions, fn decision ->
        case decision.type do
          :scrape_priority_company ->
            # Schedule high-priority scraping
            schedule_scraping(decision.target, :high)
            
          :generate_alert ->
            # Create insight alert
            create_alert(decision.message, decision.severity)
            
          :deep_analyze ->
            # Schedule deeper analysis of specific company
            schedule_deep_analysis(decision.target)
            
          _ ->
            Logger.info("🤖 Unknown decision type: #{decision.type}")
        end
      end)
    
    {:ok, actions}
  end
  
  defp schedule_scraping(_company, priority) do
    # Schedule immediate scraping for high priority
    if priority == :high do
      Task.async(fn -> Scrapers.scrape_all() end)
    end
  end
  
  defp create_alert(message, severity) do
    Logger.info("🚨 Agent Alert [#{severity}]: #{message}")
    # TODO: Store alerts in database for dashboard display
  end
  
  defp schedule_deep_analysis(company) do
    Logger.info("🔍 Scheduling deep analysis for #{company}")
    # TODO: Implement company-specific deep analysis
  end
  
  defp answer_question(question, state) do
    # Use current memory and insights to answer user questions
    recent_insights = Insights.list_recent_insights_by_company(10)
    
    context = 
      recent_insights
      |> Enum.map(fn {company, data} ->
        "#{company}: #{length(data.press_releases)} press releases, #{length(data.social_media)} social posts"
      end)
      |> Enum.join("\n")
    
    prompt = """
    You are an AI agent with access to competitive intelligence data. Answer this question based on recent data:
    
    Question: #{question}
    
    Recent data summary:
    #{context}
    
    Memory summary: #{Memory.summary(state.memory)}
    """
    
    CodexClient.ask(prompt)
  end
end