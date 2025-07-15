defmodule DashboardGenWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: DashboardGenWeb
      import Plug.Conn
      use Gettext, backend: DashboardGenWeb.Gettext
      alias DashboardGenWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
    end
  end

  defp html_helpers do
    quote do
      use Phoenix.Component
      use PetalComponents
      use Phoenix.HTML
      use Gettext, backend: DashboardGenWeb.Gettext
      alias Phoenix.LiveView.JS
      alias DashboardGenWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
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
      use Gettext, backend: DashboardGenWeb.Gettext
    end
  end

  def static_paths, do: ["assets", "favicon.ico", "robots.txt"]

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: DashboardGenWeb.Endpoint,
        router: DashboardGenWeb.Router,
        statics: DashboardGenWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
