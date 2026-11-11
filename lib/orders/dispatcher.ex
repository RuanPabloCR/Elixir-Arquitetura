defmodule Pedido.Dispatcher do
  @moduledoc "Distribui pedidos validos entre workers concorrentes."

  @type pedido_processado :: Pedido.Worker.pedido_processado()

  @spec processar([pedido_processado()], integer()) ::
          :ok | {:error, :timeout | :parametros_invalidos}
  def processar(pedidos, quantidade_workers)
      when is_list(pedidos) and is_integer(quantidade_workers) and quantidade_workers > 0 do
    if pedidos == [] do
      :ok
    else
      workers = Enum.map(1..quantidade_workers, fn _ -> Pedido.Worker.start() end)

      try do
        despachar(pedidos, workers)
      after
        Enum.each(workers, &Pedido.Worker.stop/1)
      end
    end
  end

  def processar(_pedidos, _quantidade_workers), do: {:error, :parametros_invalidos}

  defp despachar(pedidos, workers) do
    IO.puts("\n== Despachando #{length(pedidos)} pedidos para #{length(workers)} workers ==")

    pedidos
    |> Enum.with_index()
    |> Enum.each(fn {pedido, index} ->
      worker = Enum.at(workers, rem(index, length(workers)))
      send(worker, {:processar_pedido, pedido, self()})
    end)

    timeout =
      max(5_000, div(length(pedidos) + length(workers) - 1, length(workers)) * 1_000 + 5_000)

    case aguardar_conclusao(length(pedidos), timeout) do
      :ok ->
        IO.puts("== Todos os pedidos foram processados ==")
        :ok

      erro ->
        erro
    end
  end

  defp aguardar_conclusao(0, _timeout), do: :ok

  defp aguardar_conclusao(restantes, timeout) do
    receive do
      {:pedido_concluido, id, worker} ->
        IO.puts("[Dispatcher] Pedido ##{id} confirmado por #{inspect(worker)}")
        aguardar_conclusao(restantes - 1, timeout)
    after
      timeout -> {:error, :timeout}
    end
  end
end
