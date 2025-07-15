defmodule DashboardGenWeb.Gettext do
  @moduledoc false

  # Use the Gettext backend behaviour. This replaces the deprecated
  # `use Gettext` with the `otp_app:` option.
  use Gettext.Backend, otp_app: :dashboard_gen
end
