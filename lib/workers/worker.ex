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

  @spec processar(pid(), pedido_processado()) :: :ok
  def processar(pid, entrada), do: GenServer.cast(pid, {:processar, entrada})

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
  def handle_cast({:processar, %{pedido: pedido, total: total}}, state) do
    IO.puts("[Worker #{state.id}] Processando pedido ##{pedido.id} para #{pedido.cliente}: R$ #{total}")
    Process.sleep(@tempo_processamento)
    GenServer.cast(Pedido.Dispatcher, {:pedido_concluido, pedido.id, self()})
    {:noreply, state}
  end
end
