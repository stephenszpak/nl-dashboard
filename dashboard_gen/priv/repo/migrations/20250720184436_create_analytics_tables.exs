defmodule DashboardGen.Repo.Migrations.CreateAnalyticsTables do
  use Ecto.Migration

  def change do
    # Page Views Table
    create table(:analytics_page_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :page_url, :text, null: false
      add :page_title, :string, size: 500
      add :visitor_id, :string, null: false
      add :session_id, :string, null: false
      add :timestamp, :utc_datetime, null: false
      add :referrer, :text
      add :user_agent, :text
      
      # Geographic data
      add :country, :string, size: 100
      add :region, :string, size: 100
      add :city, :string, size: 100
      
      # Device/Browser data
      add :device_type, :string, size: 20
      add :browser, :string, size: 100
      add :os, :string, size: 100
      
      # Engagement metrics
      add :time_on_page, :integer
      add :scroll_depth, :float
      add :exit_page, :boolean, default: false
      
      # Custom dimensions
      add :custom_dimensions, :map
      
      timestamps(type: :utc_datetime)
    end

    # Events Table
    create table(:analytics_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :event_category, :string, size: 100, null: false
      add :event_action, :string, size: 100
      add :event_label, :string, size: 255
      add :event_value, :float
      
      # Context
      add :page_url, :text
      add :visitor_id, :string, null: false
      add :session_id, :string, null: false
      add :timestamp, :utc_datetime, null: false
      
      # Geographic data
      add :country, :string, size: 100
      add :region, :string, size: 100
      add :city, :string, size: 100
      
      # Device data
      add :device_type, :string, size: 20
      add :browser, :string, size: 100
      add :os, :string, size: 100
      
      # Custom event properties
      add :custom_properties, :map
      
      timestamps(type: :utc_datetime)
    end

    # Visitors Table
    create table(:analytics_visitors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :visitor_id, :string, null: false
      add :first_visit, :utc_datetime, null: false
      add :last_visit, :utc_datetime, null: false
      add :total_visits, :integer, default: 1
      add :total_page_views, :integer, default: 1
      add :total_events, :integer, default: 0
      add :total_time_spent, :integer, default: 0
      
      # Geographic data
      add :country, :string, size: 100
      add :region, :string, size: 100
      add :city, :string, size: 100
      
      # Device preferences
      add :device_type, :string, size: 20
      add :browser, :string, size: 100
      add :os, :string, size: 100
      
      # Acquisition data
      add :acquisition_source, :string, size: 100
      add :acquisition_medium, :string, size: 100
      add :acquisition_campaign, :string, size: 255
      add :acquisition_term, :string, size: 255
      add :acquisition_content, :string, size: 255
      
      # Behavior segments
      add :visitor_type, :string, size: 20
      add :engagement_score, :float
      add :conversion_count, :integer, default: 0
      add :lifetime_value, :float, default: 0.0
      
      # Preferences and interests
      add :interests, {:array, :string}
      add :preferred_content_types, {:array, :string}
      
      # Custom visitor attributes
      add :custom_attributes, :map
      
      timestamps(type: :utc_datetime)
    end

    # Sessions Table
    create table(:analytics_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :visitor_id, :string, null: false
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime
      add :duration, :integer
      
      # Session metrics
      add :page_views, :integer, default: 1
      add :events, :integer, default: 0
      add :bounce, :boolean, default: false
      add :exit_intent, :boolean, default: false
      
      # Journey data
      add :entry_page, :text
      add :exit_page, :text
      add :pages_visited, {:array, :string}
      add :user_journey, {:array, :map}
      
      # Conversion data
      add :conversion, :boolean, default: false
      add :conversion_type, :string, size: 50
      add :conversion_value, :float
      add :goal_completions, {:array, :string}
      
      # Context
      add :country, :string, size: 100
      add :region, :string, size: 100
      add :city, :string, size: 100
      add :device_type, :string, size: 20
      add :browser, :string, size: 100
      add :os, :string, size: 100
      
      # Traffic source
      add :traffic_source, :string, size: 100
      add :traffic_medium, :string, size: 100
      add :campaign, :string, size: 255
      add :referrer, :text
      
      # Engagement metrics
      add :engagement_score, :float
      add :scroll_depth_avg, :float
      add :interaction_events, :integer, default: 0
      
      # Custom session data
      add :custom_data, :map
      
      timestamps(type: :utc_datetime)
    end

    # Indexes for performance
    create index(:analytics_page_views, [:visitor_id])
    create index(:analytics_page_views, [:session_id])
    create index(:analytics_page_views, [:timestamp])
    create index(:analytics_page_views, [:page_url])
    create index(:analytics_page_views, [:country])
    create index(:analytics_page_views, [:device_type])

    create index(:analytics_events, [:visitor_id])
    create index(:analytics_events, [:session_id])
    create index(:analytics_events, [:timestamp])
    create index(:analytics_events, [:event_name])
    create index(:analytics_events, [:event_category])
    create index(:analytics_events, [:country])

    create unique_index(:analytics_visitors, [:visitor_id])
    create index(:analytics_visitors, [:country])
    create index(:analytics_visitors, [:visitor_type])
    create index(:analytics_visitors, [:last_visit])

    create index(:analytics_sessions, [:visitor_id])
    create unique_index(:analytics_sessions, [:session_id])
    create index(:analytics_sessions, [:start_time])
    create index(:analytics_sessions, [:conversion])
    create index(:analytics_sessions, [:country])
    create index(:analytics_sessions, [:device_type])
  end
end