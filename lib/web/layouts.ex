defmodule PedidosWeb.Layouts do
  @moduledoc "Layout raiz do painel: carrega o CSS e o cliente do LiveView."

  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="pt-BR">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>Painel de Pedidos</title>
        <link rel="stylesheet" href="/painel.css" />
      </head>
      <body>
        {@inner_content}
        <script src="/js/phoenix.min.js">
        </script>
        <script src="/js/phoenix_live_view.min.js">
        </script>
        <script src="/painel.js">
        </script>
      </body>
    </html>
    """
  end
end
