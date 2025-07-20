defmodule DashboardGen.Analytics.Event do
  @moduledoc """
  Schema for tracking user interaction events from Adobe Analytics.
  
  Represents clicks, searches, downloads, form submissions, and other
  user interactions on alliancebernstein.com.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_events" do
    field :event_name, :string
    field :event_category, :string # search, navigation, download, form, etc.
    field :event_action, :string # click, submit, view, etc.
    field :event_label, :string # specific element or content
    field :event_value, :float # numeric value if applicable
    
    # Context
    field :page_url, :string
    field :visitor_id, :string
    field :session_id, :string
    field :timestamp, :utc_datetime
    
    # Geographic data
    field :country, :string
    field :region, :string
    field :city, :string
    
    # Device data
    field :device_type, :string
    field :browser, :string
    field :os, :string
    
    # Custom event properties
    field :custom_properties, :map, default: %{}
    
    timestamps(type: :utc_datetime)
  end
  
  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_name, :event_category, :event_action, :event_label, :event_value,
      :page_url, :visitor_id, :session_id, :timestamp,
      :country, :region, :city, :device_type, :browser, :os,
      :custom_properties
    ])
    |> validate_required([:event_name, :event_category, :visitor_id, :session_id, :timestamp])
    |> validate_length(:event_name, max: 255)
    |> validate_length(:event_category, max: 100)
    |> validate_length(:event_action, max: 100)
    |> validate_inclusion(:device_type, ["mobile", "desktop", "tablet", "unknown"])
  end
end