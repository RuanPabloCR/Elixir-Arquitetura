defmodule Pedido.Worker do
  @moduledoc """
  Processa um pedido por vez e confirma a conclusao ao dispatcher.

  Cada worker tem um `id` fixo e se registra no `Pedido.Registry`, porque o PID
  muda quando o supervisor o reinicia. Ao iniciar, avisa o dispatcher, que passa
  a monitora-lo.
  """

  use GenServer

  @tempo_processamento 1_000

  @type id :: pos_integer()
  @type pedido_processado :: %{pedido: Pedido.t(), total: float()}

  @spec start_link(id()) :: GenServer.on_start()
  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: via(id))

  @spec via(id()) :: {:via, Registry, {atom(), {:worker, id()}}}
  def via(id), do: {:via, Registry, {Pedido.Registry, {:worker, id}}}

  @doc """
  Envia um pedido ao worker. `tentativa` e quantas vezes esse pedido ja falhou
  (0 na primeira vez).
  """
  @spec processar(pid(), pedido_processado(), non_neg_integer()) :: :ok
  def processar(pid, entrada, tentativa \\ 0) do
    GenServer.cast(pid, {:processar, entrada, tentativa})
  end

  @doc "PID atual do worker `id`, que muda a cada reinicio."
  @spec pid(id()) :: {:ok, pid()} | :error
  def pid(id) do
    case Registry.lookup(Pedido.Registry, {:worker, id}) do
      [{pid, _valor}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc "Simula uma falha encerrando o worker de forma abrupta (`:kill`)."
  @spec derrubar(id()) :: :ok | :error
  def derrubar(id) do
    with {:ok, pid} <- pid(id) do
      Process.exit(pid, :kill)
      :ok
    end
  end

  @impl true
  def init(id) do
    GenServer.cast(Pedido.Dispatcher, {:worker_pronto, self(), id})
    {:ok, %{id: id}}
  end

  @impl true
  def handle_cast({:processar, %{pedido: pedido}, tentativa}, state) do
    GenServer.cast(Pedido.Dispatcher, {:pedido_iniciado, pedido.id, self()})

    # Let it crash: a falha nao e tratada aqui, o supervisor reinicia o worker.
    if tentativa < pedido.falhas_simuladas do
      raise Pedido.FalhaSimulada,
        pedido_id: pedido.id,
        tentativa: tentativa,
        falhas_simuladas: pedido.falhas_simuladas
    end

    Process.sleep(@tempo_processamento)
    GenServer.cast(Pedido.Dispatcher, {:pedido_concluido, pedido.id, self()})
    {:noreply, state}
  end
end
