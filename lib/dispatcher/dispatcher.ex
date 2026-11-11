defmodule Pedido.Dispatcher do
  @moduledoc """
  Distribui pedidos entre os workers e garante que nenhum se perca.

  Mantem a fila, os workers ociosos e o pedido em andamento de cada worker.
  Monitora os workers com `Process.monitor`: se um cair, o pedido interrompido
  volta para a fila com uma tentativa a mais. Ao atingir `@max_tentativas`, vai
  para a lista de falhas.

  A fila fica em memoria: se o dispatcher cair, ela e perdida.
  """

  use GenServer

  @max_tentativas 3

  @type resumo :: %{
          concluidos: non_neg_integer(),
          reprocessados: non_neg_integer(),
          falhas: [%{pedido_id: pos_integer(), motivo: String.t()}],
          metricas: Pedido.Resultados.metricas()
        }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Coloca pedidos validos (saida do pipeline) na fila."
  @spec submeter([Pedido.Worker.pedido_processado()]) :: :ok
  def submeter(pedidos) when is_list(pedidos),
    do: GenServer.cast(__MODULE__, {:submeter, pedidos})

  @doc "Bloqueia ate a fila esvaziar e nenhum worker estar ocupado."
  @spec aguardar(timeout()) :: {:ok, resumo()}
  def aguardar(timeout \\ 30_000), do: GenServer.call(__MODULE__, :aguardar, timeout)

  @spec estado() :: map()
  def estado, do: GenServer.call(__MODULE__, :estado)

  @impl true
  def init(:ok) do
    {:ok,
     %{
       fila: :queue.new(),
       ociosos: :queue.new(),
       # pid => %{id: id_do_worker, atual: nil | %{entrada: ..., tentativas: n}}
       workers: %{},
       esperando: [],
       # Inicio (tempo monotonico, ms) do lote em andamento; nil quando ocioso.
       lote_inicio: nil
     }}
  end

  @impl true
  def handle_cast({:worker_pronto, pid, id}, state) do
    Process.monitor(pid)
    :ok = Pedido.Resultados.publicar(:worker_pronto, %{worker_id: id, pid: pid})

    state = %{
      state
      | workers: Map.put(state.workers, pid, %{id: id, atual: nil}),
        ociosos: :queue.in(pid, state.ociosos)
    }

    {:noreply, state |> despachar() |> verificar_conclusao()}
  end

  def handle_cast({:pedido_iniciado, id, pid}, state) do
    case state.workers do
      %{^pid => %{id: worker_id, atual: %{entrada: %{pedido: %{id: ^id}}}}} ->
        Pedido.Resultados.publicar(:pedido_iniciado, %{pedido_id: id, worker_id: worker_id})

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:submeter, pedidos}, state) do
    fila =
      Enum.reduce(pedidos, state.fila, fn entrada, fila ->
        :queue.in(%{entrada: entrada, tentativas: 0}, fila)
      end)

    state = if pedidos != [], do: iniciar_lote(state, length(pedidos)), else: state

    {:noreply, %{state | fila: fila} |> despachar() |> verificar_conclusao()}
  end

  def handle_cast({:pedido_concluido, id, pid}, state) do
    case state.workers do
      %{^pid => %{atual: %{entrada: %{pedido: %{id: ^id}}}} = worker} ->
        :ok =
          Pedido.Resultados.publicar(:pedido_concluido, %{pedido_id: id, worker_id: worker.id})

        state = %{
          state
          | workers: Map.put(state.workers, pid, %{worker | atual: nil}),
            ociosos: :queue.in(pid, state.ociosos)
        }

        {:noreply, state |> despachar() |> verificar_conclusao()}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:aguardar, from, state) do
    {:noreply, verificar_conclusao(%{state | esperando: [from | state.esperando]})}
  end

  def handle_call(:estado, _from, state) do
    estado =
      state
      |> resumo()
      |> Map.merge(%{
        na_fila: :queue.len(state.fila),
        workers_ativos: map_size(state.workers),
        ocupados: Enum.count(state.workers, fn {_pid, w} -> w.atual != nil end)
      })

    {:reply, estado, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Map.pop(state.workers, pid) do
      {nil, _} ->
        {:noreply, state}

      {worker, workers} ->
        # :shutdown vem de remover_worker/0: e uma remocao, nao uma falha.
        if reason == :shutdown do
          Pedido.Resultados.publicar(:worker_removido, %{worker_id: worker.id, pid: pid})
        else
          Pedido.Resultados.publicar(:worker_falhou, %{
            worker_id: worker.id,
            pid: pid,
            motivo: motivo(reason)
          })
        end

        state = %{state | workers: workers, ociosos: :queue.filter(&(&1 != pid), state.ociosos)}
        state = if worker.atual, do: reenfileirar(state, worker.atual, reason), else: state

        {:noreply, state |> despachar() |> verificar_conclusao()}
    end
  end

  # Entrega pedidos da fila aos workers ociosos enquanto houver os dois.
  defp despachar(state) do
    with {{:value, item}, fila} <- :queue.out(state.fila),
         {{:value, pid}, ociosos} <- :queue.out(state.ociosos) do
      Pedido.Worker.processar(pid, item.entrada, item.tentativas)

      despachar(%{
        state
        | fila: fila,
          ociosos: ociosos,
          workers: Map.update!(state.workers, pid, &%{&1 | atual: item})
      })
    else
      _ -> state
    end
  end

  # Um worker encerrado de proposito (:shutdown) nao conta como tentativa falha.
  defp reenfileirar(state, item, reason) do
    id = item.entrada.pedido.id
    tentativas = if reason == :shutdown, do: item.tentativas, else: item.tentativas + 1

    if tentativas >= @max_tentativas do
      Pedido.Resultados.publicar(:pedido_falhou, %{pedido_id: id, motivo: motivo(reason)})
      state
    else
      Pedido.Resultados.publicar(:pedido_reprocessado, %{pedido_id: id, tentativas: tentativas})

      %{
        state
        | fila: :queue.in_r(%{item | tentativas: tentativas}, state.fila)
      }
    end
  end

  # Excecoes chegam como {excecao, stacktrace}; mostramos so a mensagem.
  defp motivo({%{__exception__: true} = excecao, _stacktrace}), do: Exception.message(excecao)
  defp motivo(reason), do: inspect(reason)

  # Pedidos submetidos enquanto um lote esta em andamento entram nesse mesmo lote.
  defp iniciar_lote(%{lote_inicio: nil} = state, quantidade) do
    Pedido.Resultados.publicar(:lote_iniciado, %{pedidos: quantidade})
    %{state | lote_inicio: System.monotonic_time(:millisecond)}
  end

  defp iniciar_lote(state, _quantidade), do: state

  # Chamada apos cada mudanca de estado: fecha o lote e responde a quem aguarda.
  defp verificar_conclusao(state) do
    if terminou?(state) do
      state |> encerrar_lote() |> responder_esperando()
    else
      state
    end
  end

  defp encerrar_lote(%{lote_inicio: nil} = state), do: state

  defp encerrar_lote(state) do
    duracao = System.monotonic_time(:millisecond) - state.lote_inicio
    Pedido.Resultados.publicar(:lote_concluido, %{duracao_ms: duracao})
    %{state | lote_inicio: nil}
  end

  defp responder_esperando(%{esperando: []} = state), do: state

  defp responder_esperando(state) do
    resumo = resumo(state)
    Enum.each(state.esperando, &GenServer.reply(&1, {:ok, resumo}))
    %{state | esperando: []}
  end

  defp terminou?(state) do
    :queue.is_empty(state.fila) and Enum.all?(state.workers, fn {_pid, w} -> w.atual == nil end)
  end

  defp resumo(_state) do
    resultados = Pedido.Resultados.estado()

    %{
      concluidos: resultados.metricas.processados,
      reprocessados: resultados.metricas.reprocessados,
      falhas: resultados.pedidos_falhos,
      metricas: resultados.metricas
    }
  end
end
