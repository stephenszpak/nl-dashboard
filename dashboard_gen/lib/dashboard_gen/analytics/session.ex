defmodule DashboardGen.Analytics.Session do
  @moduledoc """
  Schema for tracking user sessions from Adobe Analytics.
  
  Represents individual user sessions on alliancebernstein.com
  with journey and conversion data.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_sessions" do
    field :session_id, :string
    field :visitor_id, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :duration, :integer # seconds
    
    # Session metrics
    field :page_views, :integer, default: 1
    field :events, :integer, default: 0
    field :bounce, :boolean, default: false
    field :exit_intent, :boolean, default: false
    
    # Journey data
    field :entry_page, :string
    field :exit_page, :string
    field :pages_visited, {:array, :string}, default: []
    field :user_journey, {:array, :map}, default: [] # ordered list of page/event objects
    
    # Conversion data
    field :conversion, :boolean, default: false
    field :conversion_type, :string # lead, download, contact, etc.
    field :conversion_value, :float
    field :goal_completions, {:array, :string}, default: []
    
    # Context
    field :country, :string
    field :region, :string
    field :city, :string
    field :device_type, :string
    field :browser, :string
    field :os, :string
    
    # Traffic source
    field :traffic_source, :string
    field :traffic_medium, :string
    field :campaign, :string
    field :referrer, :string
    
    # Engagement metrics
    field :engagement_score, :float # calculated based on time, interactions, etc.
    field :scroll_depth_avg, :float # average scroll depth across pages
    field :interaction_events, :integer, default: 0
    
    # Custom session data
    field :custom_data, :map, default: %{}
    
    timestamps(type: :utc_datetime)
  end
  
  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_id, :visitor_id, :start_time, :end_time, :duration,
      :page_views, :events, :bounce, :exit_intent, :entry_page, :exit_page,
      :pages_visited, :user_journey, :conversion, :conversion_type,
      :conversion_value, :goal_completions, :country, :region, :city,
      :device_type, :browser, :os, :traffic_source, :traffic_medium,
      :campaign, :referrer, :engagement_score, :scroll_depth_avg,
      :interaction_events, :custom_data
    ])
    |> validate_required([:session_id, :visitor_id, :start_time])
    |> validate_number(:page_views, greater_than: 0)
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_number(:engagement_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 10.0)
    |> validate_inclusion(:device_type, ["mobile", "desktop", "tablet", "unknown"])
    |> validate_inclusion(:conversion_type, [
      "lead", "download", "contact", "newsletter", "demo", "trial", "purchase", nil
    ])
  end
end