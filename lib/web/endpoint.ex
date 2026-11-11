defmodule PedidosWeb.Endpoint do
  @moduledoc """
  Servidor HTTP do painel. So escuta a porta com `mix phx.server`.

  Nao ha Node nem esbuild: o JavaScript do Phoenix e do LiveView e servido
  direto dos pacotes em `deps/`, e o CSS e o JS do painel ficam em `priv/static`.
  """

  use Phoenix.Endpoint, otp_app: :pedidos

  @session_options [
    store: :cookie,
    key: "_pedidos_key",
    signing_salt: Application.compile_env!(:pedidos, [__MODULE__, :session_signing_salt]),
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static, at: "/js", from: {:phoenix, "priv/static"}, only: ~w(phoenix.min.js)

  plug Plug.Static,
    at: "/js",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)

  plug Plug.Static, at: "/", from: :pedidos, only: ~w(painel.css painel.js)

  plug Plug.RequestId
  plug Plug.Session, @session_options
  plug PedidosWeb.Router
end
