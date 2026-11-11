defmodule PedidosWeb.PainelLive do
  @moduledoc """
  Painel da demonstracao: workers, metricas, eventos e controles.

  A tela nao tem regra de negocio. Ela assina os eventos de `Pedido.Resultados`
  e, a cada rajada de eventos, relê o estado (no maximo a cada
  `@intervalo_atualizacao` ms). Os botoes so chamam as mesmas funcoes que o
  `iex` usaria.
  """

  use Phoenix.LiveView

  @intervalo_atualizacao 100
  @destaque_falha_ms 2_000
  @eventos_visiveis 40
  @max_workers 200
  @tempos_ms [200, 500, 1_000, 2_000]
  @clientes ~w(Ana Bruno Carla Davi Eva Fabio Gabi Heitor Iara Joao)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      assinar()
      :timer.send_interval(500, :tick)
    end

    {:ok, socket |> assign(atualizacao_agendada?: false) |> carregar()}
  end

  # --- Eventos do sistema -----------------------------------------------------

  @impl true
  def handle_info({:pedido_evento, _evento}, %{assigns: %{atualizacao_agendada?: true}} = socket),
    do: {:noreply, socket}

  def handle_info({:pedido_evento, _evento}, socket) do
    Process.send_after(self(), :atualizar, @intervalo_atualizacao)
    {:noreply, assign(socket, atualizacao_agendada?: true)}
  end

  def handle_info(:atualizar, socket) do
    {:noreply, socket |> assign(atualizacao_agendada?: false) |> carregar()}
  end

  # Apaga o destaque vermelho dos workers que cairam ha mais de 2 s.
  def handle_info(:tick, socket) do
    if MapSet.size(socket.assigns.caidos) > 0,
      do: {:noreply, carregar(socket)},
      else: {:noreply, socket}
  end

  # Se o Resultados reiniciar, a assinatura se perde: assina de novo.
  def handle_info({:DOWN, _ref, :process, _pid, _motivo}, socket) do
    Process.send_after(self(), :reassinar, 200)
    {:noreply, socket}
  end

  def handle_info(:reassinar, socket) do
    try do
      assinar()
      {:noreply, carregar(socket)}
    catch
      :exit, _ ->
        Process.send_after(self(), :reassinar, 200)
        {:noreply, socket}
    end
  end

  # --- Controles ----------------------------------------------------------------

  @impl true
  def handle_event("derrubar", %{"id" => id}, socket) do
    Pedido.Worker.derrubar(String.to_integer(id))
    {:noreply, socket}
  end

  def handle_event("derrubar_dispatcher", _params, socket) do
    if pid = Process.whereis(Pedido.Dispatcher), do: Process.exit(pid, :kill)
    {:noreply, socket}
  end

  def handle_event("adicionar_worker", _params, socket) do
    if length(socket.assigns.workers) < @max_workers, do: Pedido.WorkerSupervisor.adicionar_worker()
    {:noreply, socket}
  end

  def handle_event("remover_worker", _params, socket) do
    Pedido.WorkerSupervisor.remover_worker()
    {:noreply, socket}
  end

  def handle_event("definir_workers", %{"quantidade" => quantidade}, socket) do
    with {n, ""} <- Integer.parse(quantidade) do
      Pedido.WorkerSupervisor.definir_quantidade(n |> max(0) |> min(@max_workers))
    end

    {:noreply, socket}
  end

  def handle_event("enviar_lote", %{"quantidade" => quantidade}, socket) do
    with {n, ""} when n > 0 <- Integer.parse(quantidade) do
      enviar(for _ <- 1..min(n, 1_000), do: pedido(0))
    end

    {:noreply, socket}
  end

  def handle_event("enviar_com_falha", _params, socket) do
    enviar([pedido(1)])
    {:noreply, socket}
  end

  def handle_event("enviar_falha_permanente", _params, socket) do
    enviar([pedido(3)])
    {:noreply, socket}
  end

  def handle_event("enviar_invalidos", _params, socket) do
    enviar([
      %{tipo: :fisico, id: proximo_id(), cliente: "", itens: [item()], frete: 10.0},
      %{tipo: :digital, id: -1, cliente: "Davi", itens: [item()]},
      %{tipo: :fisico, id: proximo_id(), cliente: "Eva", itens: [], frete: 5.0},
      %{tipo: :misterioso, id: proximo_id()}
    ])

    {:noreply, socket}
  end

  def handle_event("tempo", %{"ms" => ms}, socket) do
    Application.put_env(:pedidos, :tempo_processamento_ms, String.to_integer(ms))
    {:noreply, assign(socket, tempo_ms: String.to_integer(ms))}
  end

  # --- Estado -------------------------------------------------------------------

  defp assinar do
    {:ok, _snapshot} = Pedido.Resultados.assinar(self())
    Process.monitor(Pedido.Resultados)
  end

  defp carregar(socket) do
    resultados = Pedido.Resultados.estado()
    agora = System.system_time(:millisecond)

    caidos =
      for %{tipo: :worker_falhou, dados: %{worker_id: id}, ocorrido_em: t} <- resultados.eventos,
          agora - t < @destaque_falha_ms,
          into: MapSet.new(),
          do: id

    reinicios =
      for %{tipo: :worker_reiniciado, dados: %{worker_id: id}} <- resultados.eventos,
          reduce: %{},
          do: (acc -> Map.update(acc, id, 1, &(&1 + 1)))

    assign(socket,
      metricas: resultados.metricas,
      workers: resultados.workers |> Map.values() |> Enum.sort_by(& &1.id),
      falhas: Enum.reverse(resultados.pedidos_falhos),
      eventos: resultados.eventos |> Enum.take(-@eventos_visiveis) |> Enum.reverse(),
      caidos: caidos,
      reinicios: reinicios,
      dispatcher: estado_dispatcher(),
      tempo_ms: Application.get_env(:pedidos, :tempo_processamento_ms, 1_000),
      tempos_ms: @tempos_ms,
      max_workers: @max_workers
    )
  end

  # O Dispatcher pode estar reiniciando no momento da consulta.
  defp estado_dispatcher do
    Pedido.Dispatcher.estado()
  catch
    :exit, _ -> %{na_fila: 0, ocupados: 0, reiniciando?: true}
  end

  defp enviar(entradas) do
    %{validos: validos, invalidos: invalidos} = Pedido.Pipeline.processar(entradas)
    if invalidos != [], do: Pedido.Resultados.registrar_invalidos(invalidos)
    if validos != [], do: Pedido.Dispatcher.submeter(validos)
  end

  defp pedido(falhas_simuladas) do
    base = %{
      id: proximo_id(),
      cliente: Enum.random(@clientes),
      itens: [item()],
      falhas_simuladas: falhas_simuladas
    }

    if :rand.uniform(2) == 1,
      do: Map.merge(base, %{tipo: :fisico, frete: 15.0}),
      else: Map.put(base, :tipo, :digital)
  end

  defp item, do: %{produto: "Produto", quantidade: :rand.uniform(3), preco: 49.9}

  defp proximo_id, do: :atomics.add_get(:persistent_term.get({PedidosWeb, :ids}), 1, 1)

  # --- Visao --------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <main class="painel">
      <header class="topo">
        <div>
          <h1>Pedidos na BEAM</h1>
          <p class="sub">Workers supervisionados pelo OTP, com eventos ao vivo</p>
        </div>
        <span class={["status", @dispatcher[:reiniciando?] && "status--alerta"]}>
          <span class="ponto"></span>
          {if @dispatcher[:reiniciando?], do: "Dispatcher reiniciando", else: "Ao vivo"}
        </span>
      </header>

      <section class="metricas">
        <.metrica rotulo="Processados" valor={@metricas.processados} tom="ok" />
        <.metrica rotulo="Inválidos" valor={@metricas.invalidos} />
        <.metrica rotulo="Reprocessados" valor={@metricas.reprocessados} tom="aviso" />
        <.metrica rotulo="Falhas" valor={@metricas.falhas} tom="erro" />
        <.metrica rotulo="Reinícios" valor={@metricas.reinicios} />
        <.metrica rotulo="Na fila" valor={@dispatcher.na_fila} />
        <.metrica rotulo="Último lote" valor={tempo(@metricas.tempo_execucao_ms)} />
      </section>

      <div class="grade">
        <section class="cartao">
          <div class="cartao-topo">
            <h2>Workers <span class="contagem">{length(@workers)}</span></h2>
            <span class="detalhe">{@dispatcher.ocupados} ocupados</span>
          </div>
          <div class="legenda">
            <span><i class="amostra amostra--ocioso"></i>ocioso</span>
            <span><i class="amostra amostra--processando"></i>processando</span>
            <span><i class="amostra amostra--caiu"></i>caiu e foi reiniciado</span>
          </div>

          <div :if={@workers == []} class="vazio">Nenhum worker. Adicione nos controles.</div>

          <div class="workers">
            <div
              :for={w <- @workers}
              id={"worker-#{w.id}"}
              class={[
                "worker",
                "worker--#{w.estado}",
                MapSet.member?(@caidos, w.id) && "worker--caiu"
              ]}
            >
              <div class="worker-linha">
                <span class="worker-id">W{w.id}</span>
                <span :if={@reinicios[w.id]} class="worker-reinicios" title="Reinícios">
                  ↻ {@reinicios[w.id]}
                </span>
              </div>
              <div class="worker-pedido">
                {if w.pedido_id, do: "pedido ##{w.pedido_id}", else: "ocioso"}
              </div>
              <div class="worker-pid">{pid(w.pid)}</div>
              <button
                class="worker-derrubar"
                phx-click="derrubar"
                phx-value-id={w.id}
                title="Derrubar com Process.exit(pid, :kill)"
                aria-label={"Derrubar worker #{w.id}"}
              >
                ✕
              </button>
            </div>
          </div>
        </section>

        <aside class="lateral">
          <section class="cartao">
            <h2>Pedidos</h2>
            <form class="linha" phx-submit="enviar_lote">
              <input
                type="number"
                name="quantidade"
                value="20"
                min="1"
                max="1000"
                aria-label="Quantidade de pedidos"
              />
              <button type="submit" class="botao botao--primario">Enviar lote</button>
            </form>
            <div class="botoes">
              <button class="botao" phx-click="enviar_com_falha">Pedido que falha 1 vez</button>
              <button class="botao" phx-click="enviar_falha_permanente">
                Pedido que sempre falha
              </button>
              <button class="botao" phx-click="enviar_invalidos">Pedidos inválidos</button>
            </div>
          </section>

          <section class="cartao">
            <h2>Workers e falhas</h2>
            <div class="linha">
              <button class="botao" phx-click="remover_worker" aria-label="Remover worker">−</button>
              <form class="linha" phx-submit="definir_workers">
                <input
                  type="number"
                  name="quantidade"
                  value={length(@workers)}
                  min="0"
                  max={@max_workers}
                  aria-label="Quantidade de workers"
                />
                <button type="submit" class="botao">Definir</button>
              </form>
              <button class="botao" phx-click="adicionar_worker" aria-label="Adicionar worker">
                +
              </button>
            </div>
            <form class="linha" phx-change="tempo">
              <label for="tempo">Tempo por pedido</label>
              <select id="tempo" name="ms">
                <option :for={ms <- @tempos_ms} value={ms} selected={ms == @tempo_ms}>
                  {ms} ms
                </option>
              </select>
            </form>
            <button class="botao botao--perigo" phx-click="derrubar_dispatcher">
              Derrubar o Dispatcher
            </button>
            <p class="nota">
              O Dispatcher reinicia junto com os workers (:rest_for_one); a fila em memória é perdida e as métricas são preservadas.
            </p>
          </section>

          <section :if={@falhas != []} class="cartao">
            <h2>Lista de falhas <span class="contagem">{length(@falhas)}</span></h2>
            <ul class="falhas">
              <li :for={f <- Enum.take(@falhas, 10)}>
                <strong>#{f.pedido_id}</strong> {f.motivo}
              </li>
            </ul>
          </section>
        </aside>
      </div>

      <section class="cartao">
        <h2>Eventos</h2>
        <ol class="eventos">
          <li :for={e <- @eventos} class={"evento evento--#{e.tipo}"}>
            <time>{hora(e.ocorrido_em)}</time>
            <span>{descricao(e)}</span>
          </li>
        </ol>
      </section>
    </main>
    """
  end

  attr :rotulo, :string, required: true
  attr :valor, :any, required: true
  attr :tom, :string, default: nil

  defp metrica(assigns) do
    ~H"""
    <div class={["metrica", @tom && "metrica--#{@tom}"]}>
      <span class="metrica-valor">{@valor}</span>
      <span class="metrica-rotulo">{@rotulo}</span>
    </div>
    """
  end

  defp tempo(nil), do: "—"
  defp tempo(ms) when ms < 1_000, do: "#{ms} ms"
  defp tempo(ms), do: "#{Float.round(ms / 1_000, 1)} s"

  defp pid(pid), do: pid |> inspect() |> String.replace_prefix("#PID", "")

  defp descricao(evento),
    do: evento |> Pedido.Terminal.formatar() |> String.replace_prefix("[Evento] ", "")

  defp hora(ms) do
    {_data, {h, m, s}} = :calendar.system_time_to_local_time(ms, :millisecond)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> IO.iodata_to_binary()
  end
end
