# DashboardGen

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `dashboard_gen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dashboard_gen, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
  be found at <https://hexdocs.pm/dashboard_gen>.

## Running the app

The development configuration now reads the HTTP port from the `PORT`
environment variable. It defaults to `4000`. If that port is already in
use, start the server on another port with:

```bash
PORT=4001 mix phx.server
```

