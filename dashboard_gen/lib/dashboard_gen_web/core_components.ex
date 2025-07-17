defmodule DashboardGenWeb.CoreComponents do
  @moduledoc """
  A small collection of shared UI components for the application.
  Currently this module only exposes the `icon/1` component used in
  LiveView templates.
  """
  use Phoenix.Component

  @doc """Render an SVG icon from the assets/icons directory."""
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global, default: %{}
  def icon(assigns) do
    ~H"""
    <svg {@rest} class={@class} aria-hidden="true">
      <use href={"/icons/#{@name}.svg#icon"}></use>
    </svg>
    """
  end
end
