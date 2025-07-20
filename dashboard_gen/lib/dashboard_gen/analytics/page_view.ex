defmodule DashboardGen.Analytics.PageView do
  @moduledoc """
  Schema for tracking page views from Adobe Analytics.
  
  Represents individual page view events on alliancebernstein.com
  with comprehensive metadata for analysis.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_page_views" do
    field :page_url, :string
    field :page_title, :string
    field :visitor_id, :string
    field :session_id, :string
    field :timestamp, :utc_datetime
    field :referrer, :string
    field :user_agent, :string
    
    # Geographic data
    field :country, :string
    field :region, :string
    field :city, :string
    
    # Device/Browser data
    field :device_type, :string # mobile, desktop, tablet
    field :browser, :string
    field :os, :string
    
    # Engagement metrics
    field :time_on_page, :integer # seconds
    field :scroll_depth, :float # percentage
    field :exit_page, :boolean, default: false
    
    # Custom dimensions (Adobe Analytics custom variables)
    field :custom_dimensions, :map, default: %{}
    
    timestamps(type: :utc_datetime)
  end
  
  @doc false
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, [
      :page_url, :page_title, :visitor_id, :session_id, :timestamp,
      :referrer, :user_agent, :country, :region, :city,
      :device_type, :browser, :os, :time_on_page, :scroll_depth,
      :exit_page, :custom_dimensions
    ])
    |> validate_required([:page_url, :visitor_id, :session_id, :timestamp])
    |> validate_length(:page_url, max: 2000)
    |> validate_length(:page_title, max: 500)
    |> validate_inclusion(:device_type, ["mobile", "desktop", "tablet", "unknown"])
  end
end