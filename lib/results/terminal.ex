defmodule Pedido.Terminal do
  @moduledoc """
  Consome os eventos do sistema e os apresenta no terminal.

  Ate `habilitar_saida/0` ser chamada, os eventos ficam pendentes (no maximo
  `@max_pendentes`). A escolha fica no ambiente da aplicacao, e nao no estado do
  processo, para sobreviver a um reinicio: se o Dispatcher cair, o
  `:rest_for_one` tambem reinicia o Terminal, que deve continuar exibindo.
  """

  use GenServer

  @max_pendentes 500

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))

  @doc "Libera a exibicao dos eventos que chegaram desde a inicializacao da aplicacao."
  @spec habilitar_saida() :: :ok
  def habilitar_saida do
    Application.put_env(:pedidos, :saida_terminal, true)
    GenServer.call(__MODULE__, :habilitar_saida)
  end

  @impl true
  def init(:ok) do
    {:ok, _snapshot} = Pedido.Resultados.assinar(self())

    {:ok,
     %{
       habilitado?: Application.get_env(:pedidos, :saida_terminal, false),
       pendentes: :queue.new()
     }}
  end

  @impl true
  def handle_call(:habilitar_saida, _from, state) do
    Enum.each(:queue.to_list(state.pendentes), &IO.puts(formatar(&1)))

    {:reply, :ok, %{state | habilitado?: true, pendentes: :queue.new()}}
  end

  @impl true
  def handle_info({:pedido_evento, evento}, %{habilitado?: false} = state) do
    pendentes = :queue.in(evento, state.pendentes)

    pendentes =
      if :queue.len(pendentes) > @max_pendentes,
        do: elem(:queue.out(pendentes), 1),
        else: pendentes

    {:noreply, %{state | pendentes: pendentes}}
  end

  def handle_info({:pedido_evento, evento}, state) do
    IO.puts(formatar(evento))
    {:noreply, state}
  end

  defp formatar(%{tipo: :worker_iniciado, dados: dados}) do
    "[Evento] Worker #{dados.worker_id} iniciado (#{inspect(dados.pid)})"
  end

  defp formatar(%{tipo: :worker_reiniciado, dados: dados}) do
    "[Evento] Worker #{dados.worker_id} reiniciado (#{inspect(dados.pid)})"
  end

  defp formatar(%{tipo: :worker_falhou, dados: dados}) do
    "[Evento] Worker #{dados.worker_id} falhou: #{dados.motivo}"
  end

  defp formatar(%{tipo: :pedido_iniciado, dados: dados}) do
    "[Evento] Worker #{dados.worker_id} iniciou o pedido ##{dados.pedido_id}"
  end

  defp formatar(%{tipo: :pedido_concluido, dados: dados}) do
    "[Evento] Pedido ##{dados.pedido_id} concluido pelo worker #{dados.worker_id}"
  end

  defp formatar(%{tipo: :pedido_reprocessado, dados: dados}) do
    "[Evento] Pedido ##{dados.pedido_id} reenfileirado (tentativa #{dados.tentativas})"
  end

  defp formatar(%{tipo: :pedido_falhou, dados: dados}) do
    "[Evento] Pedido ##{dados.pedido_id} enviado para falhas: #{dados.motivo}"
  end

  defp formatar(%{tipo: :pedido_invalido, dados: dados}) do
    "[Evento] Pedido invalido #{inspect(dados.pedido_id)}: #{dados.motivo}"
  end

  defp formatar(%{tipo: :worker_removido, dados: dados}) do
    "[Evento] Worker #{dados.worker_id} removido"
  end

  defp formatar(%{tipo: :lote_iniciado, dados: dados}) do
    "[Evento] Lote iniciado com #{dados.pedidos} pedidos"
  end

  defp formatar(%{tipo: :lote_concluido, dados: dados}) do
    "[Evento] Lote concluido em #{dados.duracao_ms} ms"
  end

  defp formatar(%{tipo: tipo, dados: dados}), do: "[Evento] #{tipo}: #{inspect(dados)}"
end
