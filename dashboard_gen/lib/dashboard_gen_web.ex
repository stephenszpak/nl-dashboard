defmodule DashboardGenWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: DashboardGenWeb
      import Plug.Conn
      import DashboardGenWeb.Gettext
      alias DashboardGenWeb.Router.Helpers, as: Routes
    end
  end

  defp html_helpers do
    quote do
      use Phoenix.Component
      use PetalComponents
      import Phoenix.HTML
      import DashboardGenWeb.Gettext
      alias DashboardGenWeb.Router.Helpers, as: Routes
    end
  end

  def html do
    quote do
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DashboardGenWeb.Layouts, :root}

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import DashboardGenWeb.Gettext
    end
  end

  def static_paths, do: ["assets", "favicon.ico", "robots.txt"]

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
