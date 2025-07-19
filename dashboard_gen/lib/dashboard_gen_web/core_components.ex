defmodule DashboardGenWeb.CoreComponents do
  @moduledoc """
  A small collection of shared UI components for the application.
  Currently this module only exposes the `icon/1` component used in
  LiveView templates.
  """
  use Phoenix.Component

  @doc """
  Render an SVG icon from the assets/icons directory.
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global, default: %{})

  def icon(assigns) do
    ~H"""
    <svg {@rest} class={@class} aria-hidden="true">
      <use href={"/icons/#{@name}.svg#icon"}></use>
    </svg>
    """
  end

  @doc """
  AB styled button component
  """
  attr(:variant, :string, default: "primary")
  attr(:class, :string, default: nil)
  attr(:rest, :global, default: %{})
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button class={[button_classes(@variant), @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_classes("primary"),
    do: "px-4 py-2 rounded-md bg-brandBlue text-white hover:bg-[#1A86B5]"

  defp button_classes("secondary"),
    do: "px-4 py-2 rounded-md border border-brandBlue text-brandBlue hover:bg-[#e6f7fd]"

  @doc """
  Text input component with AB styles
  """
  attr(:rest, :global, default: %{})

  def text_input(assigns) do
    ~H"""
    <input class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:border-brandBlue focus:ring-1 focus:ring-brandBlue" {@rest} />
    """
  end
end
