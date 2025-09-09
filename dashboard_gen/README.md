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

## Port Configuration

Copy `.env.example` to `.env` and adjust the following values as needed:

- `DB_HOST_PORT`: host port for PostgreSQL (default: 5434)
- `APP_HOST_PORT`: host port for web application (default: 4000)
- `PORT`: internal port for the web application inside the container (default: 4000)
