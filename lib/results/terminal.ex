defmodule Pedido.Terminal do
  @moduledoc "Consome os eventos do sistema e os apresenta no terminal."

  use GenServer

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, Keyword.put(opts, :name, __MODULE__))

  @doc "Libera a exibicao dos eventos que chegaram desde a inicializacao da aplicacao."
  @spec habilitar_saida() :: :ok
  def habilitar_saida, do: GenServer.call(__MODULE__, :habilitar_saida)

  @impl true
  def init(:ok) do
    {:ok, _snapshot} = Pedido.Resultados.assinar(self())
    {:ok, %{habilitado?: false, pendentes: :queue.new()}}
  end

  @impl true
  def handle_call(:habilitar_saida, _from, state) do
    Enum.each(:queue.to_list(state.pendentes), &IO.puts(formatar(&1)))

    {:reply, :ok, %{state | habilitado?: true, pendentes: :queue.new()}}
  end

  @impl true
  def handle_info({:pedido_evento, evento}, %{habilitado?: false} = state) do
    {:noreply, %{state | pendentes: :queue.in(evento, state.pendentes)}}
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
end
