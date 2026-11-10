defmodule Pedido.Validacao do
  @moduledoc """
  Converte dados brutos (mapas) em structs de pedido.

  Erros esperados voltam como `{:error, motivo}`; nenhuma excecao e lancada.
  """

  @spec validar(term()) :: {:ok, Pedido.t()} | {:error, String.t()}
  def validar(%{tipo: :fisico} = dados) do
    with :ok <- validar_base(dados),
         :ok <- validar_frete(Map.get(dados, :frete, 0.0)) do
      {:ok, struct!(PedidoFisico, Map.delete(dados, :tipo))}
    end
  end

  def validar(%{tipo: :digital} = dados) do
    with :ok <- validar_base(dados) do
      {:ok, struct!(PedidoDigital, Map.drop(dados, [:tipo, :frete]))}
    end
  end

  def validar(%{tipo: tipo}), do: {:error, "tipo desconhecido: #{inspect(tipo)}"}
  def validar(%{}), do: {:error, "campo obrigatorio ausente: tipo"}
  def validar(_), do: {:error, "pedido deve ser um mapa"}

  defp validar_base(dados) do
    with :ok <- validar_id(Map.get(dados, :id)),
         :ok <- validar_cliente(Map.get(dados, :cliente)),
         :ok <- validar_itens(Map.get(dados, :itens)) do
      validar_falhas(Map.get(dados, :falhas_simuladas, 0))
    end
  end

  defp validar_id(id) when is_integer(id) and id > 0, do: :ok
  defp validar_id(id), do: {:error, "id deve ser um inteiro positivo: #{inspect(id)}"}

  defp validar_cliente(cliente) when is_binary(cliente) do
    if String.trim(cliente) == "", do: {:error, "cliente vazio"}, else: :ok
  end

  defp validar_cliente(_), do: {:error, "cliente ausente"}

  defp validar_itens([_ | _] = itens) do
    Enum.find_value(itens, :ok, fn item ->
      case validar_item(item) do
        :ok -> nil
        erro -> erro
      end
    end)
  end

  defp validar_itens(_), do: {:error, "o pedido precisa de ao menos um item"}

  defp validar_item(%{produto: produto, quantidade: qtd, preco: preco})
       when is_binary(produto) and produto != "" and is_integer(qtd) and qtd > 0 and
              is_number(preco) and preco >= 0,
       do: :ok

  defp validar_item(item), do: {:error, "item invalido: #{inspect(item)}"}

  defp validar_frete(frete) when is_number(frete) and frete >= 0, do: :ok
  defp validar_frete(frete), do: {:error, "frete invalido: #{inspect(frete)}"}

  defp validar_falhas(n) when is_integer(n) and n >= 0, do: :ok
  defp validar_falhas(n), do: {:error, "falhas_simuladas invalido: #{inspect(n)}"}
end
