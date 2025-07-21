defmodule DashboardGenWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dashboard_gen

  # The session will be stored in the cookie and signed.
  @session_options [
    store: :cookie,
    key: "_dashboard_gen_key",
    signing_salt: "signsalt"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/",
    from: :dashboard_gen,
    gzip: false,
    only: DashboardGenWeb.static_paths()
  )

  if code_reloading? do
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :dashboard_gen)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])
  
  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(DashboardGenWeb.Router)
end
