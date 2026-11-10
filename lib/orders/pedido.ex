defmodule Pedido do
  @moduledoc """
  Tipos compartilhados pelos pedidos e funcoes comuns a todos eles.
  """

  @type item :: %{produto: String.t(), quantidade: pos_integer(), preco: number()}
  @type t :: PedidoFisico.t() | PedidoDigital.t()

  @doc "Soma `quantidade * preco` de todos os itens."
  @spec subtotal([item()]) :: float()
  def subtotal(itens) do
    Enum.reduce(itens, 0.0, fn %{quantidade: q, preco: p}, acc -> acc + q * p end)
  end
end

defprotocol Pedido.Total do
  @moduledoc """
  Polimorfismo: cada tipo de pedido sabe calcular o proprio total.
  """

  @spec calcular(t()) :: float()
  def calcular(pedido)
end
