defmodule Pedido.WorkerSupervisor do
  @moduledoc """
  Supervisor dinamico dos workers: a quantidade e definida em tempo de execucao.

  Um worker que cai e reiniciado sozinho, com o mesmo `id`. O limite de reinicios
  e alto para permitir derrubar varios workers seguidos na demonstracao.
  """

  use DynamicSupervisor

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 100, max_seconds: 5)
  end

  @doc "Inicia os workers `1..quantidade`."
  @spec iniciar(pos_integer()) :: :ok
  def iniciar(quantidade) when is_integer(quantidade) and quantidade >= 1 do
    Enum.each(1..quantidade, &iniciar_worker/1)
  end

  @spec iniciar_worker(Pedido.Worker.id()) :: DynamicSupervisor.on_start_child()
  def iniciar_worker(id), do: DynamicSupervisor.start_child(__MODULE__, {Pedido.Worker, id})

  @spec adicionar_worker() :: DynamicSupervisor.on_start_child()
  def adicionar_worker, do: iniciar_worker(Enum.max(ids(), fn -> 0 end) + 1)

  @doc "Encerra o worker de maior id. O pedido em andamento volta para a fila."
  @spec remover_worker() :: :ok | :error
  def remover_worker do
    with [_ | _] = ids <- ids(),
         {:ok, pid} <- Pedido.Worker.pid(Enum.max(ids)) do
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    else
      _ -> :error
    end
  end

  @spec ids() :: [Pedido.Worker.id()]
  def ids do
    Registry.select(Pedido.Registry, [{{{:worker, :"$1"}, :_, :_}, [], [:"$1"]}])
  end
end
