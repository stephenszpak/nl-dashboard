defmodule DashboardGen.Analytics.Visitor do
  @moduledoc """
  Schema for tracking unique visitors from Adobe Analytics.
  
  Represents aggregated visitor data and behavior patterns
  for alliancebernstein.com users.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_visitors" do
    field :visitor_id, :string
    field :first_visit, :utc_datetime
    field :last_visit, :utc_datetime
    field :total_visits, :integer, default: 1
    field :total_page_views, :integer, default: 1
    field :total_events, :integer, default: 0
    field :total_time_spent, :integer, default: 0 # seconds
    
    # Geographic data
    field :country, :string
    field :region, :string
    field :city, :string
    
    # Device preferences
    field :device_type, :string
    field :browser, :string
    field :os, :string
    
    # Acquisition data
    field :acquisition_source, :string # google, direct, social, etc.
    field :acquisition_medium, :string # organic, cpc, email, etc.
    field :acquisition_campaign, :string
    field :acquisition_term, :string
    field :acquisition_content, :string
    
    # Behavior segments
    field :visitor_type, :string # new, returning, loyal
    field :engagement_score, :float # calculated engagement metric
    field :conversion_count, :integer, default: 0
    field :lifetime_value, :float, default: 0.0
    
    # Preferences and interests (derived from behavior)
    field :interests, {:array, :string}, default: []
    field :preferred_content_types, {:array, :string}, default: []
    
    # Custom visitor attributes
    field :custom_attributes, :map, default: %{}
    
    timestamps(type: :utc_datetime)
  end
  
  @doc false
  def changeset(visitor, attrs) do
    visitor
    |> cast(attrs, [
      :visitor_id, :first_visit, :last_visit, :total_visits, :total_page_views,
      :total_events, :total_time_spent, :country, :region, :city,
      :device_type, :browser, :os, :acquisition_source, :acquisition_medium,
      :acquisition_campaign, :acquisition_term, :acquisition_content,
      :visitor_type, :engagement_score, :conversion_count, :lifetime_value,
      :interests, :preferred_content_types, :custom_attributes
    ])
    |> validate_required([:visitor_id, :first_visit, :last_visit])
    |> unique_constraint(:visitor_id)
    |> validate_number(:total_visits, greater_than: 0)
    |> validate_number(:total_page_views, greater_than: 0)
    |> validate_number(:engagement_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 10.0)
    |> validate_inclusion(:visitor_type, ["new", "returning", "loyal", "unknown"])
    |> validate_inclusion(:device_type, ["mobile", "desktop", "tablet", "unknown"])
  end
end