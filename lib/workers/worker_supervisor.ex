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

  @doc """
  Child spec que inicia os workers iniciais de forma sincrona, durante a subida
  da arvore. Retorna `:ignore`, porque nao deixa nenhum processo vivo; por ser
  `:transient`, roda de novo quando o `:rest_for_one` reinicia a arvore.
  """
  @spec workers_iniciais(pos_integer()) :: Supervisor.child_spec()
  def workers_iniciais(quantidade) do
    %{
      id: :workers_iniciais,
      start: {__MODULE__, :iniciar_e_ignorar, [quantidade]},
      restart: :transient
    }
  end

  @doc false
  def iniciar_e_ignorar(quantidade) do
    iniciar(quantidade)
    :ignore
  end

  @doc "Adiciona ou remove workers ate restarem exatamente `quantidade`."
  @spec definir_quantidade(non_neg_integer()) :: :ok
  def definir_quantidade(quantidade) when is_integer(quantidade) and quantidade >= 0 do
    atual = length(ids())

    cond do
      atual < quantidade -> Enum.each(1..(quantidade - atual), fn _ -> adicionar_worker() end)
      atual > quantidade -> Enum.each(1..(atual - quantidade), fn _ -> remover_worker() end)
      true -> :ok
    end

    :ok
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
