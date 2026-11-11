defmodule Pedido.Resultados do
  @moduledoc """
  Mantem metricas, estado atual dos workers e os eventos recentes do sistema.

  Consumidores podem consultar `estado/0` e assinar eventos com `assinar/1`.
  """

  use GenServer

  @max_eventos 2_000

  @type evento :: %{
          sequencia: pos_integer(),
          tipo: atom(),
          dados: map(),
          ocorrido_em: integer()
        }

  @type metricas :: %{
          processados: non_neg_integer(),
          invalidos: non_neg_integer(),
          reprocessados: non_neg_integer(),
          falhas: non_neg_integer(),
          reinicios: non_neg_integer()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))

  @doc "Publica um evento, atualiza as metricas e notifica os assinantes."
  @spec publicar(atom(), map()) :: :ok
  def publicar(tipo, dados \\ %{}), do: GenServer.call(__MODULE__, {:publicar, tipo, dados})

  @doc "Registra os pedidos rejeitados pelo pipeline sem adicionar efeitos colaterais nele."
  @spec registrar_invalidos([map()]) :: :ok
  def registrar_invalidos(invalidos),
    do: GenServer.call(__MODULE__, {:registrar_invalidos, invalidos})

  @doc "Assina eventos e retorna um snapshot consistente para inicializar um consumidor."
  @spec assinar(pid()) :: {:ok, map()}
  def assinar(pid \\ self()), do: GenServer.call(__MODULE__, {:assinar, pid})

  @spec desassinar(pid()) :: :ok
  def desassinar(pid \\ self()), do: GenServer.call(__MODULE__, {:desassinar, pid})

  @doc "Retorna metricas, workers, falhas finais e os eventos recentes."
  @spec estado() :: map()
  def estado, do: GenServer.call(__MODULE__, :estado)

  @spec metricas() :: metricas()
  def metricas, do: GenServer.call(__MODULE__, :metricas)

  @impl true
  def init(:ok) do
    {:ok,
     %{
       metricas: %{processados: 0, invalidos: 0, reprocessados: 0, falhas: 0, reinicios: 0},
       eventos: :queue.new(),
       sequencia: 0,
       assinantes: %{},
       workers: %{},
       workers_vistos: MapSet.new(),
       pedidos_falhos: []
     }}
  end

  @impl true
  def handle_call({:publicar, :worker_pronto, %{worker_id: id} = dados}, _from, state) do
    tipo =
      if MapSet.member?(state.workers_vistos, id), do: :worker_reiniciado, else: :worker_iniciado

    state = %{state | workers_vistos: MapSet.put(state.workers_vistos, id)}
    {:reply, :ok, registrar_evento(state, tipo, dados)}
  end

  def handle_call({:publicar, tipo, dados}, _from, state) do
    {:reply, :ok, registrar_evento(state, tipo, dados)}
  end

  def handle_call({:registrar_invalidos, invalidos}, _from, state) do
    state =
      Enum.reduce(invalidos, state, fn %{entrada: entrada, motivo: motivo}, acc ->
        pedido_id = if is_map(entrada), do: Map.get(entrada, :id), else: nil
        registrar_evento(acc, :pedido_invalido, %{pedido_id: pedido_id, motivo: motivo})
      end)

    {:reply, :ok, state}
  end

  def handle_call({:assinar, pid}, _from, state) do
    state = assinar_pid(state, pid)
    {:reply, {:ok, snapshot(state)}, state}
  end

  def handle_call({:desassinar, pid}, _from, state) do
    {:reply, :ok, desassinar_pid(state, pid)}
  end

  def handle_call(:metricas, _from, state), do: {:reply, state.metricas, state}

  def handle_call(:estado, _from, state), do: {:reply, snapshot(state), state}

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    assinantes =
      case state.assinantes do
        %{^pid => ^ref} -> Map.delete(state.assinantes, pid)
        _ -> state.assinantes
      end

    {:noreply, %{state | assinantes: assinantes}}
  end

  defp assinar_pid(state, pid) do
    if Map.has_key?(state.assinantes, pid) do
      state
    else
      Map.put(state, :assinantes, Map.put(state.assinantes, pid, Process.monitor(pid)))
    end
  end

  defp desassinar_pid(state, pid) do
    case Map.pop(state.assinantes, pid) do
      {nil, assinantes} ->
        %{state | assinantes: assinantes}

      {ref, assinantes} ->
        Process.demonitor(ref, [:flush])
        %{state | assinantes: assinantes}
    end
  end

  defp registrar_evento(state, tipo, dados) do
    evento = %{
      sequencia: state.sequencia + 1,
      tipo: tipo,
      dados: dados,
      ocorrido_em: System.system_time(:millisecond)
    }

    Enum.each(state.assinantes, fn {pid, _ref} -> send(pid, {:pedido_evento, evento}) end)

    eventos = :queue.in(evento, state.eventos)

    eventos =
      if :queue.len(eventos) > @max_eventos, do: elem(:queue.out(eventos), 1), else: eventos

    state
    |> Map.put(:eventos, eventos)
    |> Map.put(:sequencia, evento.sequencia)
    |> atualizar_metricas(tipo, dados)
    |> atualizar_workers(tipo, dados)
  end

  defp atualizar_metricas(state, :pedido_concluido, _dados), do: incrementar(state, :processados)
  defp atualizar_metricas(state, :pedido_invalido, _dados), do: incrementar(state, :invalidos)

  defp atualizar_metricas(state, :pedido_reprocessado, _dados),
    do: incrementar(state, :reprocessados)

  defp atualizar_metricas(state, :pedido_falhou, dados) do
    state
    |> incrementar(:falhas)
    |> Map.update!(:pedidos_falhos, &[dados | &1])
  end

  defp atualizar_metricas(state, :worker_reiniciado, _dados), do: incrementar(state, :reinicios)
  defp atualizar_metricas(state, _tipo, _dados), do: state

  defp incrementar(state, chave) do
    put_in(state, [:metricas, chave], Map.fetch!(state.metricas, chave) + 1)
  end

  defp atualizar_workers(state, tipo, %{worker_id: id} = dados)
       when tipo in [:worker_iniciado, :worker_reiniciado] do
    worker = %{id: id, pid: dados.pid, estado: :ocioso, pedido_id: nil}
    put_in(state, [:workers, id], worker)
  end

  defp atualizar_workers(state, :worker_falhou, %{worker_id: id}) do
    update_in(state, [:workers, id], fn
      nil -> nil
      worker -> %{worker | estado: :falhou}
    end)
  end

  defp atualizar_workers(state, :pedido_iniciado, %{worker_id: id, pedido_id: pedido_id}) do
    update_in(state, [:workers, id], fn
      nil -> nil
      worker -> %{worker | estado: :processando, pedido_id: pedido_id}
    end)
  end

  defp atualizar_workers(state, :pedido_concluido, %{worker_id: id}) do
    update_in(state, [:workers, id], fn
      nil -> nil
      worker -> %{worker | estado: :ocioso, pedido_id: nil}
    end)
  end

  defp atualizar_workers(state, _tipo, _dados), do: state

  defp snapshot(state) do
    %{
      metricas: state.metricas,
      workers: state.workers,
      pedidos_falhos: Enum.reverse(state.pedidos_falhos),
      sequencia: state.sequencia,
      eventos: :queue.to_list(state.eventos)
    }
  end
end
