defmodule Pedido.Pipeline do
  @moduledoc """
  Recebe uma lista de pedidos brutos, valida cada um e separa validos de invalidos.
  """

  @type resultado :: %{
          validos: [%{pedido: Pedido.t(), total: float()}],
          invalidos: [%{entrada: term(), motivo: String.t()}]
        }

  @spec processar([term()]) :: resultado()
  def processar(entradas) do
    {validos, invalidos} =
      entradas
      |> Enum.map(fn entrada -> {entrada, Pedido.Validacao.validar(entrada)} end)
      |> Enum.split_with(fn {_entrada, resultado} -> match?({:ok, _}, resultado) end)

    %{
      validos: Enum.map(validos, fn {_, {:ok, pedido}} -> transformar(pedido) end),
      invalidos: Enum.map(invalidos, fn {entrada, {:error, motivo}} -> %{entrada: entrada, motivo: motivo} end)
    }
  end

  defp transformar(pedido) do
    %{pedido: pedido, total: pedido |> Pedido.Total.calcular() |> Float.round(2)}
  end
end
