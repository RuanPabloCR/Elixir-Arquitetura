defmodule Pedidos.Application do
  @moduledoc """
  Inicia a arvore de supervisao, com dois ramos independentes (`:one_for_one`):

  - `Pedidos.Nucleo` (`:rest_for_one`): se o Dispatcher cair, ele e os workers
    sao reiniciados (os workers precisam se anunciar ao novo dispatcher). Se um
    worker cair, somente o `Pedido.WorkerSupervisor` o reinicia.
  - Web (PubSub e Endpoint do painel): fica fora do nucleo para que derrubar o
    Dispatcher na demonstracao nao desconecte o painel.
  """

  use Application

  @workers_iniciais 5

  @impl true
  def start(_type, _args) do
    quantidade = Application.get_env(:pedidos, :workers, @workers_iniciais)

    # Contador de ids dos pedidos criados pelo painel.
    :persistent_term.put({PedidosWeb, :ids}, :atomics.new(1, []))

    nucleo = [
      {Registry, keys: :unique, name: Pedido.Registry},
      Pedido.Resultados,
      Pedido.Dispatcher,
      Pedido.WorkerSupervisor,
      Pedido.Terminal,
      # Sincrono: quando a aplicacao termina de subir, os workers ja existem.
      Pedido.WorkerSupervisor.workers_iniciais(quantidade)
    ]

    children = [
      %{
        id: Pedidos.Nucleo,
        type: :supervisor,
        start: {Supervisor, :start_link, [nucleo, [strategy: :rest_for_one, name: Pedidos.Nucleo]]}
      },
      {Phoenix.PubSub, name: Pedidos.PubSub},
      PedidosWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pedidos.Supervisor)
  end
end
