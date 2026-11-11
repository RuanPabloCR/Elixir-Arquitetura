defmodule Pedido.Worker do
  @moduledoc """
  Processa pedidos de forma isolada e confirma a conclusao ao dispatcher.
  """

  @type pedido_processado :: %{pedido: Pedido.t(), total: float()}

  @spec start() :: pid()
  def start do
    spawn(fn -> loop() end)
  end

  @spec stop(pid()) :: :ok
  def stop(pid) do
    send(pid, :parar)
    :ok
  end

  defp loop do
    receive do
      {:processar_pedido, %{pedido: pedido, total: total}, dispatcher_pid} ->
        IO.puts(
          "[Worker #{inspect(self())}] Processando pedido ##{pedido.id} para #{pedido.cliente}: R$ #{total}"
        )

        Process.sleep(1_000)
        IO.puts("[Worker #{inspect(self())}] Pedido ##{pedido.id} concluido")
        send(dispatcher_pid, {:pedido_concluido, pedido.id, self()})
        loop()

      :parar ->
        :ok
    end
  end
end
