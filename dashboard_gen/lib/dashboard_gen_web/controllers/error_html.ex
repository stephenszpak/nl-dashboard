defmodule DashboardGenWeb.ErrorHTML do
  use DashboardGenWeb, :html

  # If you want to customize your error pages, uncomment and
  # edit the embed_templates/1 call below to point to your
  # custom 404.html.heex and 500.html.heex pages.
  embed_templates "error_html/*"

  # Phoenix will render a status message from the template name.
  # For example, "404.html" becomes "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

