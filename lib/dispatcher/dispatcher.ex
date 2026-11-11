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
          falhas: [%{pedido_id: pos_integer(), motivo: term()}]
        }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Coloca pedidos validos (saida do pipeline) na fila."
  @spec submeter([Pedido.Worker.pedido_processado()]) :: :ok
  def submeter(pedidos) when is_list(pedidos), do: GenServer.cast(__MODULE__, {:submeter, pedidos})

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
       concluidos: 0,
       reprocessados: 0,
       falhas: [],
       esperando: []
     }}
  end

  @impl true
  def handle_cast({:worker_pronto, pid, id}, state) do
    Process.monitor(pid)
    IO.puts("[Dispatcher] Worker #{id} pronto (#{inspect(pid)})")

    state = %{
      state
      | workers: Map.put(state.workers, pid, %{id: id, atual: nil}),
        ociosos: :queue.in(pid, state.ociosos)
    }

    {:noreply, state |> despachar() |> responder_se_terminou()}
  end

  def handle_cast({:submeter, pedidos}, state) do
    fila =
      Enum.reduce(pedidos, state.fila, fn entrada, fila ->
        :queue.in(%{entrada: entrada, tentativas: 0}, fila)
      end)

    {:noreply, %{state | fila: fila} |> despachar() |> responder_se_terminou()}
  end

  def handle_cast({:pedido_concluido, id, pid}, state) do
    case state.workers do
      %{^pid => %{atual: %{entrada: %{pedido: %{id: ^id}}}} = worker} ->
        IO.puts("[Dispatcher] Pedido ##{id} confirmado pelo worker #{worker.id}")

        state = %{
          state
          | workers: Map.put(state.workers, pid, %{worker | atual: nil}),
            ociosos: :queue.in(pid, state.ociosos),
            concluidos: state.concluidos + 1
        }

        {:noreply, state |> despachar() |> responder_se_terminou()}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:aguardar, from, state) do
    {:noreply, responder_se_terminou(%{state | esperando: [from | state.esperando]})}
  end

  def handle_call(:estado, _from, state) do
    estado =
      state
      |> resumo()
      |> Map.merge(%{
        na_fila: :queue.len(state.fila),
        workers: map_size(state.workers),
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
        IO.puts("[Dispatcher] Worker #{worker.id} caiu (#{inspect(reason)})")

        state = %{state | workers: workers, ociosos: :queue.filter(&(&1 != pid), state.ociosos)}
        state = if worker.atual, do: reenfileirar(state, worker.atual, reason), else: state

        {:noreply, state |> despachar() |> responder_se_terminou()}
    end
  end

  # Entrega pedidos da fila aos workers ociosos enquanto houver os dois.
  defp despachar(state) do
    with {{:value, item}, fila} <- :queue.out(state.fila),
         {{:value, pid}, ociosos} <- :queue.out(state.ociosos) do
      Pedido.Worker.processar(pid, item.entrada)

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
      IO.puts("[Dispatcher] Pedido ##{id} esgotou #{@max_tentativas} tentativas: lista de falhas")
      %{state | falhas: [%{pedido_id: id, motivo: reason} | state.falhas]}
    else
      IO.puts("[Dispatcher] Pedido ##{id} volta para a fila (tentativa #{tentativas} de #{@max_tentativas})")

      %{
        state
        | fila: :queue.in_r(%{item | tentativas: tentativas}, state.fila),
          reprocessados: state.reprocessados + 1
      }
    end
  end

  defp responder_se_terminou(%{esperando: []} = state), do: state

  defp responder_se_terminou(state) do
    if terminou?(state) do
      resumo = resumo(state)
      Enum.each(state.esperando, &GenServer.reply(&1, {:ok, resumo}))
      %{state | esperando: []}
    else
      state
    end
  end

  defp terminou?(state) do
    :queue.is_empty(state.fila) and Enum.all?(state.workers, fn {_pid, w} -> w.atual == nil end)
  end

  defp resumo(state) do
    %{
      concluidos: state.concluidos,
      reprocessados: state.reprocessados,
      falhas: Enum.reverse(state.falhas)
    }
  end
end
