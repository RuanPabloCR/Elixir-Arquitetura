import Config

# Painel web (Phoenix LiveView). O servidor HTTP so sobe com `mix phx.server`;
# `mix run demo.exs` e `mix run escala.exs` continuam sem servidor.
#
# As chaves abaixo sao de desenvolvimento local, sem valor fora desta maquina.
config :pedidos, PedidosWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  adapter: Bandit.PhoenixAdapter,
  secret_key_base: "hol1TLkLfy2z9ujvITkR2AplC8a0csan/GoAQu6FvGzQIJIUDiUqaDPVo+qQrhKx",
  live_view: [signing_salt: "ZuMVrSzXxAs"],
  session_signing_salt: "SMd5Os4putY",
  pubsub_server: Pedidos.PubSub,
  render_errors: [formats: [html: PedidosWeb.ErroHTML], layout: false]

config :phoenix, :json_library, Jason
