defmodule Pedidos.Application do
  @moduledoc """
  Inicia a arvore de supervisao.

  `:rest_for_one`: se o Dispatcher cair, ele e os workers sao reiniciados (os
  workers precisam se anunciar ao novo dispatcher). Se um worker cair, somente o
  `Pedido.WorkerSupervisor` o reinicia.
  """

  use Application

  @workers_iniciais 5

  @impl true
  def start(_type, _args) do
    quantidade = Application.get_env(:pedidos, :workers, @workers_iniciais)

    children = [
      {Registry, keys: :unique, name: Pedido.Registry},
      Pedido.Dispatcher,
      Pedido.WorkerSupervisor,
      Supervisor.child_spec({Task, fn -> Pedido.WorkerSupervisor.iniciar(quantidade) end},
        id: :workers_iniciais,
        restart: :transient
      )
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: Pedidos.Supervisor)
  end
end
